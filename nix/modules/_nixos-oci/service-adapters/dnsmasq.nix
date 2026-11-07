# dnsmasq: healthcheck via DNS query + stop signal.
#
# dnsmasq runs in foreground by default in NixOS (--keep-in-foreground).
# No foreground adapter needed.
#
# Healthcheck: sends a raw DNS query to the configured listen address and
# port and checks that *any* bytes come back, using bash's built-in
# /dev/udp redirection -- no external DNS client. Uses "localhost" as the
# query name, answered by a default `address=/localhost/127.0.0.1` entry
# below, so the healthcheck always has a guaranteed local match and never
# depends on a consumer's own hosts-file/address config.
#
# `bind-interfaces` is set below for a related but distinct reason: by
# default (--bind-dynamic, dnsmasq's modern default) dnsmasq does a
# per-query netlink round-trip to the kernel to verify the receiving
# interface before answering *any* query, including ones with a clean
# local match. Caught live via strace against a running container: a
# query arrives (recvmsg succeeds, correct bytes), dnsmasq opens a
# netlink socket and sends an interface-verification request, and no
# DNS reply is ever sent back, for any query, including ones dnsmasq is
# explicitly configured to answer (confirmed by querying both an
# unconfigured name and one covered by a user's own `address=` entry --
# both got zero response). `bind-interfaces` uses the older, static
# per-interface binding mode and skips that runtime netlink dependency
# entirely; verified live that queries succeed immediately once this is
# set. This was the actual mechanism behind docs-ci-deploy-bp5's "dig
# gets no response" -- independent of dig, independent of the UDP
# healthcheck probe above, and independent of the image-closure-size
# issue also fixed in this adapter (see below).
#
# Previously this shelled out to `dig` (added via extraPackages). That
# pulled in the full bind.dnsutils closure -- bind-lib, libxml2, jemalloc,
# liburcu, libuv, protobuf-c, fstrm -- roughly 590 MiB of libraries with
# nothing to do with dnsmasq or with sending one UDP packet. Combined with
# dnsmasq's own surprisingly large closure (it pulls in nftables and
# systemd-minimal), the image's nix store closure ballooned to ~1.5-2 GiB,
# and nix2container's `nix:` copy transport walks that closure file by
# file to assemble layers. Caught live via strace during a hung CI image
# load: skopeo's worker threads were walking locale files from completely
# unrelated packages (e.g. diffutils' translation files) just to finish
# copying this image. That made the image slow to load even in complete
# isolation (measured ~290s with no other containers competing for I/O),
# and under any contention (the real "deploy" shard runs 8 containers'
# loads in parallel) that regularly blew past CI's job timeout -- the
# underlying cause of docs-ci-deploy-bp5, not a dnsmasq config problem.
#
# /bin/sh in every healthcheck-enabled container is already a symlink to
# bashInteractive (see nix/modules/_nixos-oci/healthcheck/outputs.nix), so
# this adds no new package at all.
#
# StopSignal: SIGTERM -- dnsmasq exits cleanly on SIGTERM.
{
  config,
  lib,
  ...
}:
let
  cfg = config.oci.container;
  isDnsmasq = cfg.mainService == "dnsmasq";
  dnsmasqCfg = config.services.dnsmasq;
  port = toString (dnsmasqCfg.settings.port or 53);
  rawAddr = dnsmasqCfg.settings.listen-address or "127.0.0.1";
  # NixOS settings can produce a list or comma-separated string
  listenAddr = if builtins.isList rawAddr then builtins.head rawAddr else rawAddr;
  # Use first address if multiple are configured
  firstAddr = builtins.head (lib.splitString "," listenAddr);
  # A wildcard bind address ("0.0.0.0"/"*"/"::") is not a usable query
  # target: dig has to connect to a concrete address, and sending a
  # UDP query to 0.0.0.0 is unreliable (varies by kernel/resolver and
  # reliably times out in some sandboxes). dnsmasq bound to a wildcard
  # address also answers on loopback, so query that instead.
  addr =
    if
      builtins.elem firstAddr [
        "0.0.0.0"
        "*"
        "::"
      ]
    then
      "127.0.0.1"
    else
      firstAddr;
in
{
  config = lib.mkIf isDnsmasq {
    oci.container._output.detectedPorts = [ (dnsmasqCfg.settings.port or 53) ];
    # Raw DNS query over bash's /dev/udp, read with a bounded timeout via
    # the `read` builtin -- no external command, so nothing here can
    # exceed podman's external --health-timeout the way dig's own
    # retry budget could. Keep generous retries/startPeriod so a
    # slow-booting VM under CPU contention doesn't flip this unhealthy
    # before dnsmasq settles.
    #
    # `-N 1`, not `-N 2` or more: bash's `read -N n` on a UDP socket can
    # issue multiple single-byte read() syscalls to satisfy the request.
    # Each individual read() on a UDP socket consumes (and discards) the
    # *entire* pending datagram regardless of the requested buffer size,
    # so asking for 2+ bytes means the first syscall eats and discards
    # the whole reply, and the second syscall then blocks forever
    # waiting for a new datagram that never arrives -- read -t 3 would
    # time out on every single check. Verified live: `-N 2` reliably
    # read only the first byte and hung; `-N 1` (one syscall, one
    # datagram, fully consumed) succeeds immediately. We only need to
    # know *that* a reply arrived, not read any of its content.
    oci.container.healthcheck.command = lib.mkDefault [
      "exec 3<>/dev/udp/${addr}/${port} && printf '\\xaa\\xaa\\x01\\x00\\x00\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x09localhost\\x00\\x00\\x01\\x00\\x01' >&3 && read -t 3 -N 1 -u 3 _reply"
    ];
    oci.container.healthcheck.timeout = lib.mkDefault 8;
    oci.container.healthcheck.startPeriod = lib.mkDefault 10;
    oci.container.healthcheck.retries = lib.mkDefault 5;
    oci.container.stopSignal = lib.mkDefault "SIGTERM";

    # See the header comment above: skips the per-query netlink interface
    # check that otherwise silently swallows every query.
    services.dnsmasq.settings.bind-interfaces = lib.mkDefault true;
    # Guarantees the healthcheck's "localhost" query always has a local
    # match, regardless of whether a consumer configures their own
    # hosts-file/address entries. `address` is a list-typed setting, so
    # this merges additively with any consumer-supplied entries rather
    # than overriding them.
    services.dnsmasq.settings.address = lib.mkDefault [ "/localhost/127.0.0.1" ];

    # nixpkgs' `services.dnsmasq` module adds
    #   conf-file = /etc/dnsmasq-conf.conf
    #   resolv-file = /etc/dnsmasq-resolv.conf
    # to the generated dnsmasq.conf whenever `resolveLocalQueries` is
    # true (the default). On a normal NixOS host those paths are
    # created by the service's preStart `touch /etc/dnsmasq-{conf,
    # resolv}.conf`. Inside a container the entrypoint script does
    # run those touches, but the OCI image's /etc is a nix-store-
    # backed directory where the overlay cannot persist the new
    # files reliably: dnsmasq --test then exits with
    #   dnsmasq: cannot read /etc/dnsmasq-conf.conf: No such file ...
    #   exit=3 (EC_FILE)
    # which systemd surfaces as `status=3/NOTIMPLEMENTED`.
    #
    # Containers never want the local-resolver wiring anyway (there
    # is no /etc/resolv.conf to splice ourselves into), so disable
    # `resolveLocalQueries` by default. Both config lines disappear
    # from the generated dnsmasq.conf, the touches become
    # irrelevant, and dnsmasq --test passes. Consumers who need the
    # local resolver on their host can still opt back in.
    services.dnsmasq.resolveLocalQueries = lib.mkDefault false;

    # nixpkgs' `services.dnsmasq` hard-codes a D-Bus-dependent ExecStart:
    #   Type = "dbus";
    #   BusName = "uk.org.thekelleys.dnsmasq";
    #   ExecStart = "${dnsmasq}/bin/dnsmasq -k --enable-dbus --user=dnsmasq ...";
    # Containers run with no dbus daemon, so `--enable-dbus` makes dnsmasq
    # exit immediately with status 5 (ExitFailure, surfaced by systemd as
    # NOTINSTALLED), and the container crash-loops. Strip the D-Bus
    # dependency here: the service becomes a plain `simple` unit, the
    # ExecStart drops `--enable-dbus`, and the BusName / Type fields are
    # cleared. Reload stays as SIGHUP (the one `kill -HUP $MAINPID`
    # command does not need dbus).
    #
    # --pid-file=/tmp/dnsmasq.pid: even with -k (keep in foreground),
    # dnsmasq writes a pidfile when started as root, defaulting to
    # /var/run/dnsmasq.pid. The OCI image has no /var/run, and dnsmasq
    # treats the failed O_EXCL open as fatal:
    #   dnsmasq: failed to open pidfile /var/run/dnsmasq.pid: No such file ...
    #   exit=3 (EC_FILE, surfaced by systemd as NOTIMPLEMENTED)
    # /tmp exists in every nix-oci rootfs and each container start gets a
    # fresh overlay, so the O_EXCL create never collides with a stale file.
    # (Verified: `--pid-file=/dev/null` fails with EEXIST and an empty
    # `--pid-file=` is a config error, so a real path is the only option.)
    systemd.services.dnsmasq.serviceConfig = {
      Type = lib.mkForce "simple";
      BusName = lib.mkForce null;
      ExecStart = lib.mkForce "${dnsmasqCfg.package}/bin/dnsmasq -k --user=dnsmasq --pid-file=/tmp/dnsmasq.pid -C ${dnsmasqCfg.configFile}";
    };
  };
}
