# NixOS: systemd load services using nix2container passthru copy scripts.
#
# Three loading strategies:
#   1. Registry push (oci.registry.enable) — copyToRegistry to localhost registry.
#      Enables SOCI lazy pull and layer dedup via containerd snapshotters.
#   2. Docker daemon — copyToDockerDaemon (direct load, no snapshotter benefit).
#   3. Podman — copyToPodman (direct load to containers-storage).
{ ... }:
{
  flake.modules.nixos.nix-oci-load-services =
    {
      config,
      lib,
      pkgs,
      skopeoTurbo ? null,
      ...
    }:
    let
      cfg = config.oci;
      reg = cfg.registry;
      deployLib = import ../../../../lib/deploy.nix { inherit lib; };
      useRegistry = reg.enable;
    in
    {
      config = lib.mkIf cfg.enable {
        systemd.services = lib.mapAttrs' (
          name: container:
          let
            registry = if useRegistry then reg else null;
            script = deployLib.copyScript {
              backend = cfg.backend;
              inherit container registry;
            };
            registryRef = deployLib.registryImageRef {
              inherit registry container;
            };
            # For registry push, override the destination to localhost:port/name:tag
            #
            # The push is built directly with skopeo rather than through
            # the image.copyToRegistry passthru script: that script
            # hardcodes `nix:${container.image}` as skopeo's first
            # positional arg ahead of "$@", so any flag appended after
            # it (e.g. --dest-tls-verify=false) lands *after* skopeo's
            # positional-arg boundary and gets misparsed as a second
            # image reference instead of a flag (reproduced live:
            # skopeo errored with "Container IMAGE-NAME uses a
            # transport:details format" trying to parse the flag
            # string as a reference). Flags have to precede both
            # positionals, so the invocation is built from scratch here
            # -- same approach as mkPushApp.nix's proven `skopeo copy
            # --dest-tls-verify=... nix:$img docker://...` ordering.
            #
            # This also picks the turbo-patched skopeo + --dest-soci
            # flags for performance.turbo.soci containers, matching
            # mkPushApp.nix: without it the push would still succeed
            # but silently produce a plain image with no SOCI zTOC
            # referrer attached.
            #
            # systemd's after/requires on docker-registry.service only
            # guarantees the unit is "active" -- not that the registry
            # has finished its own internal startup and is actually
            # accepting connections yet. Pushing immediately races that
            # startup window and fails intermittently (reproduced live:
            # the push's Main process exited at 63.2s, two seconds
            # before the registry's own "listening on ..." log line at
            # 65.3s). Poll the registry's own API before pushing,
            # exactly like the test harness's own one-off registry-push
            # script already does for the same reason.
            perf = container.performance or { };
            turboEnabled = perf.turbo.enable or false;
            sociEnabled = turboEnabled && (perf.turbo.soci or false);
            sociSpanSize = perf.turbo.sociSpanSize or 4194304;
            compression = perf.compression or "gzip";
            compressFlag =
              if compression == "zstd" then
                "--dest-compress-format zstd"
              else if compression == "gzip:estargz" then
                "--dest-compress-format gzip:estargz"
              else
                "";
            sociFlag = lib.optionalString sociEnabled "--dest-soci --dest-soci-span-size=${toString sociSpanSize}";
            skopeoPackage = if sociEnabled && skopeoTurbo != null then skopeoTurbo else pkgs.skopeo;
            execStart =
              if useRegistry then
                let
                  regUrl = "docker://${registryRef}";
                  waitAndPush = pkgs.writeShellScript "oci-load-${name}-registry-push" ''
                    set -euo pipefail
                    for _i in $(seq 1 120); do
                      if ${pkgs.curl}/bin/curl -sf http://${reg.host}:${toString reg.port}/v2/ >/dev/null 2>&1; then
                        break
                      fi
                      sleep 0.5
                    done
                    exec ${skopeoPackage}/bin/skopeo --insecure-policy copy \
                      --dest-tls-verify=false ${compressFlag} ${sociFlag} \
                      nix:${container.image} ${regUrl}
                  '';
                in
                "${waitAndPush}"
              else
                "${script}/bin/${script.name}";
          in
          lib.nameValuePair "oci-load-${name}" {
            description =
              if useRegistry then
                "Push OCI image ${container.imageRef} to registry ${reg.host}:${toString reg.port}"
              else
                "Load OCI image ${container.imageRef} into ${cfg.backend}";
            after = [
              "network.target"
            ]
            ++ lib.optional (cfg.backend == "docker" && !useRegistry) "docker.service"
            ++ lib.optional useRegistry "docker-registry.service";
            requires =
              lib.optional (cfg.backend == "docker" && !useRegistry) "docker.service"
              ++ lib.optional useRegistry "docker-registry.service";
            wantedBy = [ "multi-user.target" ];

            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = execStart;
            };
          }
        ) cfg.containers;
      };
    };
}
