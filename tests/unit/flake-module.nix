# Unit tests — nix-unit integration for lib function tests.
#
# nix-lib already generates flake.tests from the `tests = { ... }` fields
# in nix-lib.lib.oci.* declarations (16+ functions have inline tests).
#
# nix-unit's flake-parts module:
# 1. Copies flake.tests → perSystem.nix-unit.tests.system-agnostic
# 2. Generates perSystem.checks.nix-unit (runs nix-unit in sandbox)
#
# So `nix flake check` automatically runs all lib unit tests.
{ inputs, ... }:
let
  checksLib = import ../../nix/lib/container-checks.nix;
  ociLib = import ../../nix/lib/oci.nix;
in
{
  imports = [
    inputs.nix-lib.inputs.nix-unit.modules.flake.default
  ];

  perSystem =
    { lib, ... }:
    let
      checks = checksLib { inherit lib; };
      oci = ociLib { inherit lib; };

      # Helper: build a seccomp profile data attrset for a given profile/mode.
      mkTestProfile =
        {
          profile ? "moderate",
          mode ? "enforce",
        }:
        oci.mkSeccompProfileData {
          hardening.seccomp = {
            enable = true;
            inherit profile mode;
            customProfileJson = null;
          };
        };

      # Helper: get the syscall names from the first (main) rule of a profile.
      mainRuleNames = data: (builtins.head data.syscalls).names;

      # Helper: check if a syscall name appears in the main rule.
      hasInMainRule = data: name: builtins.elem name (mainRuleNames data);

      # Helper: check if profile has an arg-filtered rule matching a syscall name.
      hasArgFilterFor =
        data: syscallName:
        builtins.any (rule: (rule ? args) && builtins.elem syscallName rule.names) data.syscalls;

      # Helper: find arg filter rules for a given syscall name.
      argFiltersFor =
        data: syscallName:
        builtins.filter (rule: (rule ? args) && builtins.elem syscallName rule.names) data.syscalls;
    in
    {
      nix-unit.allowNetwork = true;
      nix-unit.inputs = {
        inherit (inputs)
          nixpkgs
          nix-lib
          flake-parts
          import-tree
          nix2container
          ;
      };

      nix-unit.tests = {
        # ── checks lib ──────────────────────────────────────────────
        "test hasNixStoreConflict detects hostStore + installNix conflict" = {
          expr = checks.hasNixStoreConflict {
            nix.hostStore = true;
            installNix = true;
          };
          expected = true;
        };
        "test hasNixStoreConflict detects hostDaemon + installNix conflict" = {
          expr = checks.hasNixStoreConflict {
            nix.hostDaemon = true;
            installNix = true;
          };
          expected = true;
        };
        "test hasNixStoreConflict no conflict with hostStore only" = {
          expr = checks.hasNixStoreConflict {
            nix.hostStore = true;
            installNix = false;
          };
          expected = false;
        };
        "test hasNixStoreConflict no conflict with installNix only" = {
          expr = checks.hasNixStoreConflict {
            nix.hostStore = false;
            installNix = true;
          };
          expected = false;
        };
        "test hasNixStoreConflict no conflict when both disabled" = {
          expr = checks.hasNixStoreConflict { };
          expected = false;
        };

        # ── seccomp: profile structure ──────────────────────────────

        "test seccomp strict profile has ERRNO default action" = {
          expr = (mkTestProfile { profile = "strict"; }).defaultAction;
          expected = "SCMP_ACT_ERRNO";
        };
        "test seccomp moderate profile has ALLOW default action" = {
          expr = (mkTestProfile { profile = "moderate"; }).defaultAction;
          expected = "SCMP_ACT_ALLOW";
        };
        "test seccomp web-server profile has ERRNO default action" = {
          expr = (mkTestProfile { profile = "web-server"; }).defaultAction;
          expected = "SCMP_ACT_ERRNO";
        };
        "test seccomp database profile has ERRNO default action" = {
          expr = (mkTestProfile { profile = "database"; }).defaultAction;
          expected = "SCMP_ACT_ERRNO";
        };
        "test seccomp all profiles have both architectures" = {
          expr = (mkTestProfile { profile = "strict"; }).architectures;
          expected = [
            "SCMP_ARCH_X86_64"
            "SCMP_ARCH_AARCH64"
          ];
        };

        # ── seccomp: io_uring blocking ──────────────────────────────

        "test seccomp moderate blocks io_uring_setup" = {
          expr = hasInMainRule (mkTestProfile { profile = "moderate"; }) "io_uring_setup";
          expected = true;
        };
        "test seccomp moderate blocks io_uring_enter" = {
          expr = hasInMainRule (mkTestProfile { profile = "moderate"; }) "io_uring_enter";
          expected = true;
        };
        "test seccomp moderate blocks io_uring_register" = {
          expr = hasInMainRule (mkTestProfile { profile = "moderate"; }) "io_uring_register";
          expected = true;
        };
        "test seccomp strict does not allow io_uring_setup" = {
          expr = hasInMainRule (mkTestProfile { profile = "strict"; }) "io_uring_setup";
          expected = false;
        };
        "test seccomp web-server does not allow io_uring_setup" = {
          expr = hasInMainRule (mkTestProfile { profile = "web-server"; }) "io_uring_setup";
          expected = false;
        };

        # ── seccomp: memfd blocking ─────────────────────────────────

        "test seccomp moderate blocks memfd_create" = {
          expr = hasInMainRule (mkTestProfile { profile = "moderate"; }) "memfd_create";
          expected = true;
        };
        "test seccomp moderate blocks memfd_secret" = {
          expr = hasInMainRule (mkTestProfile { profile = "moderate"; }) "memfd_secret";
          expected = true;
        };
        "test seccomp strict does not allow memfd_create" = {
          expr = hasInMainRule (mkTestProfile { profile = "strict"; }) "memfd_create";
          expected = false;
        };

        # ── seccomp: personality blocking ───────────────────────────

        "test seccomp moderate blocks personality" = {
          expr = hasInMainRule (mkTestProfile { profile = "moderate"; }) "personality";
          expected = true;
        };

        # ── seccomp: clone arg filtering ────────────────────────────

        "test seccomp web-server has clone arg filter" = {
          expr = hasArgFilterFor (mkTestProfile { profile = "web-server"; }) "clone";
          expected = true;
        };
        "test seccomp web-server has clone3 arg filter" = {
          expr = hasArgFilterFor (mkTestProfile { profile = "web-server"; }) "clone3";
          expected = true;
        };
        "test seccomp database has clone arg filter" = {
          expr = hasArgFilterFor (mkTestProfile { profile = "database"; }) "clone";
          expected = true;
        };
        "test seccomp moderate has clone arg filter" = {
          expr = hasArgFilterFor (mkTestProfile { profile = "moderate"; }) "clone";
          expected = true;
        };
        "test seccomp clone arg filter uses MASKED_EQ op" = {
          expr =
            let
              filters = argFiltersFor (mkTestProfile { profile = "web-server"; }) "clone";
              firstArg = builtins.head (builtins.head filters).args;
            in
            firstArg.op;
          expected = "SCMP_CMP_MASKED_EQ";
        };
        "test seccomp clone arg filter masks namespace bits" = {
          expr =
            let
              filters = argFiltersFor (mkTestProfile { profile = "web-server"; }) "clone";
              firstArg = builtins.head (builtins.head filters).args;
            in
            firstArg.value;
          expected = 2114060416; # 0x7E020080
        };

        # ── seccomp: socket arg filtering ───────────────────────────

        "test seccomp web-server has socket arg filter" = {
          expr = hasArgFilterFor (mkTestProfile { profile = "web-server"; }) "socket";
          expected = true;
        };
        "test seccomp web-server blocks AF_NETLINK (16)" = {
          expr =
            let
              filters = argFiltersFor (mkTestProfile { profile = "web-server"; }) "socket";
              values = map (f: (builtins.head f.args).value) filters;
            in
            builtins.elem 16 values;
          expected = true;
        };
        "test seccomp web-server blocks AF_PACKET (17)" = {
          expr =
            let
              filters = argFiltersFor (mkTestProfile { profile = "web-server"; }) "socket";
              values = map (f: (builtins.head f.args).value) filters;
            in
            builtins.elem 17 values;
          expected = true;
        };
        "test seccomp strict has no socket arg filter" = {
          expr = hasArgFilterFor (mkTestProfile { profile = "strict"; }) "socket";
          expected = false;
        };

        # ── seccomp: ioctl arg filtering ────────────────────────────

        "test seccomp strict has ioctl arg filter" = {
          expr = hasArgFilterFor (mkTestProfile { profile = "strict"; }) "ioctl";
          expected = true;
        };
        "test seccomp web-server has ioctl arg filter" = {
          expr = hasArgFilterFor (mkTestProfile { profile = "web-server"; }) "ioctl";
          expected = true;
        };
        "test seccomp blocks TIOCSTI (21522)" = {
          expr =
            let
              filters = argFiltersFor (mkTestProfile { profile = "strict"; }) "ioctl";
              values = map (f: (builtins.head f.args).value) filters;
            in
            builtins.elem 21522 values;
          expected = true;
        };
        "test seccomp blocks TIOCLINUX (21532)" = {
          expr =
            let
              filters = argFiltersFor (mkTestProfile { profile = "strict"; }) "ioctl";
              values = map (f: (builtins.head f.args).value) filters;
            in
            builtins.elem 21532 values;
          expected = true;
        };

        # ── seccomp: database profile specifics ─────────────────────

        "test seccomp database allows fadvise64" = {
          expr = hasInMainRule (mkTestProfile { profile = "database"; }) "fadvise64";
          expected = true;
        };
        "test seccomp database allows msync" = {
          expr = hasInMainRule (mkTestProfile { profile = "database"; }) "msync";
          expected = true;
        };
        "test seccomp database allows getgroups" = {
          expr = hasInMainRule (mkTestProfile { profile = "database"; }) "getgroups";
          expected = true;
        };
        "test seccomp database allows network syscalls" = {
          expr = hasInMainRule (mkTestProfile { profile = "database"; }) "socket";
          expected = true;
        };
        "test seccomp strict does not allow fadvise64" = {
          expr = hasInMainRule (mkTestProfile { profile = "strict"; }) "fadvise64";
          expected = false;
        };

        # ── seccomp: audit mode ─────────────────────────────────────

        "test seccomp audit mode changes default to LOG for allowlist profile" = {
          expr =
            (mkTestProfile {
              profile = "web-server";
              mode = "audit";
            }).defaultAction;
          expected = "SCMP_ACT_LOG";
        };
        "test seccomp audit mode keeps ALLOW default for moderate" = {
          expr =
            (mkTestProfile {
              profile = "moderate";
              mode = "audit";
            }).defaultAction;
          expected = "SCMP_ACT_ALLOW";
        };
        "test seccomp audit mode changes ERRNO rules to LOG in moderate" = {
          expr =
            let
              data = mkTestProfile {
                profile = "moderate";
                mode = "audit";
              };
            in
            (builtins.head data.syscalls).action;
          expected = "SCMP_ACT_LOG";
        };
        "test seccomp audit mode preserves ALLOW rules" = {
          expr =
            let
              data = mkTestProfile {
                profile = "web-server";
                mode = "audit";
              };
            in
            (builtins.head data.syscalls).action;
          expected = "SCMP_ACT_ALLOW";
        };
        "test seccomp enforce mode keeps ERRNO default" = {
          expr =
            (mkTestProfile {
              profile = "strict";
              mode = "enforce";
            }).defaultAction;
          expected = "SCMP_ACT_ERRNO";
        };
      };
    };
}
