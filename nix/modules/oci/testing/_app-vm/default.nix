# Dendritic VM node module for the bdd-app-<container> smoke tests.
#
# Replaces the imperative `mkAppsNode` function previously defined in
# ../test-apps.nix. Callers now compose a NixOS test node by importing
# this module (alongside the nix-oci + nix-oci-test NixOS modules they
# already have in scope) and setting `oci.testing.appVm.apps = <attrset>`
# plus any resource overrides via `oci.testing.appVm.resources.*`.
#
# Rationale: the per-container `bdd-app-<name>` split (one VM per
# container, scheduled by Nix's --max-jobs) forced every VM to inherit
# the old monolith sizing (8 cores / 4 GiB / 32 GiB) because the shared
# `mkAppsNode` function hard-coded those values. The module form lets a
# per-container test file override any knob with `mkOverride` without
# touching the shared builder; new strategies land as options, not forks.
#
# Scope: only the per-container app-load VMs. The aggregate
# `_bddAppsCheck` monolith (if ever revived) can import this module and
# override `resources.*` back to the big-VM defaults.
#
# This module intentionally does NOT import `nix-oci` or `nix-oci-test`
# itself. Those live in the flake-parts `flake.modules.nixos.*` tree,
# which is only resolvable from the flake-parts scope (test-apps.nix),
# not from inside a NixOS test node. The caller imports them alongside
# this module. The caller also owns the test driver's `testScript`.
{
  config,
  lib,
  ...
}:
let
  cfg = config.oci.testing.appVm;
in
{
  options.oci.testing.appVm = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.apps != { };
      defaultText = lib.literalExpression "config.oci.testing.appVm.apps != { }";
      description = ''
        Whether to activate the app-vm NixOS config (services,
        virtualisation sizing, backend wiring). Defaults to true when
        `apps` is non-empty.
      '';
    };

    apps = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = ''
        Flake apps to load into podman via nix-oci-app-<name>.service
        systemd oneshots. Keys are app names (e.g. oci-load-podman-foo),
        values are the matching flake-apps attrset entries (program,
        type, meta). Populated by callers from
        `config.oci.flake.apps` filtered to the container of interest.
      '';
    };

    backend = lib.mkOption {
      type = lib.types.enum [
        "podman"
        "docker"
      ];
      default = "podman";
      description = ''
        Container backend inside the VM. `podman` is the default and the
        only backend currently exercised by `bdd-app-<name>`; `docker`
        is wired in for forward compatibility with the SOCI/docker test
        matrix.
      '';
    };

    parallelStrategy = lib.mkOption {
      type = lib.types.enum [
        "sequential"
        "wantedBy"
        "no-block"
      ];
      default = "wantedBy";
      description = ''
        How systemd starts the `nix-oci-app-<name>.service` oneshots.

        - `wantedBy` (default): each unit gets
          `wantedBy = [ "multi-user.target" ]` + `before = [ "multi-user.target" ]`,
          so `machine.wait_for_unit("multi-user.target")` blocks until
          every oneshot has reached `active`. systemd's job scheduler
          runs them in parallel subject to `DefaultTasksMax` and any
          explicit `After=/Requires=` edges (none between app units by
          default). This is the fastest and simplest shape; the only
          cost is that a failed oneshot aborts VM boot rather than
          producing a per-app subtest failure.
        - `sequential`: the test driver loops `systemctl start` per
          unit, blocking on each `Type=oneshot`. Produces per-app
          subtest output but serializes at the driver (~15min * N on
          cold storage for the aggregate monolith; moot for one-app
          per-container VMs).
        - `no-block`: driver fires `systemctl start --no-block` for
          every unit then waits for each in a second pass. Hybrid:
          parallel execution with per-app visibility.
      '';
    };

    resources = {
      cores = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1;
        description = ''
          Virtual CPUs. skopeo decompress is single-threaded; 1 vCPU is
          enough for a single-image per-container VM, and keeps CPU
          contention low when the Nix scheduler runs N VMs in parallel
          via `--max-jobs N`. Override to 2 for tests that boot a real
          service inside the VM and run assertions concurrently.
        '';
      };

      memoryMiB = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1024;
        description = ''
          Guest RAM in MiB. Floor for systemd + udev + journald +
          podman + a single skopeo decompress of a medium image is
          roughly 700 MiB; 1 GiB gives modest headroom without
          starving the host when N VMs run concurrently. Previously
          1.5 GiB; dropped after confirming the host OOM-pressure
          pattern. Override up for probe tests that load heavier
          multi-layer images.
        '';
      };

      diskGiB = lib.mkOption {
        type = lib.types.ints.positive;
        default = 2;
        description = ''
          Scratch disk in GiB. One image extracts to a few hundred MB
          on the containers-storage overlay for a typical case; 2 GiB
          is enough for the single-image per-container VM shape.
          QEMU allocates sparsely so the host footprint is only
          what's written. Override up for probe tests with large
          layer stacks.
        '';
      };

      msize = lib.mkOption {
        type = lib.types.ints.positive;
        default = 16384;
        description = ''
          9p max packet size. nixos-test default. The monolith raises
          it to 131072 to speed /nix/store reads. Per-container VMs
          hold this buffer in host RAM N times under `--max-jobs N`,
          so stay at the default; the per-VM read volume is small.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    testing = {
      enable = true;
      appScripts = cfg.apps;
    };

    oci = {
      enable = true;
      backend = cfg.backend;
    };

    virtualisation = {
      cores = lib.mkForce cfg.resources.cores;
      memorySize = lib.mkForce cfg.resources.memoryMiB;
      diskSize = lib.mkForce (cfg.resources.diskGiB * 1024);
      msize = lib.mkForce cfg.resources.msize;
    };

    # Parallel strategy: wire each nix-oci-app-<name>.service to boot
    # with multi-user.target so systemd's parallel job scheduler runs
    # them concurrently. The sequential and no-block strategies leave
    # the services as unanchored oneshots and let the testScript drive
    # them explicitly (via `../test-apps.nix` mkAppsTestScript).
    systemd.services = lib.mkIf (cfg.parallelStrategy == "wantedBy") (
      lib.mapAttrs' (
        appName: _:
        lib.nameValuePair "nix-oci-app-${appName}" {
          wantedBy = [ "multi-user.target" ];
          before = [ "multi-user.target" ];
        }
      ) cfg.apps
    );
  };
}
