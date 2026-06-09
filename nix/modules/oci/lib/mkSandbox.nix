# OCI mkSandbox - Generate a bubblewrap sandbox script for a container
#
# Uses the container's buildEnv root filesystem with /nix/store
# bind-mounted read-only. Provides filesystem and PID isolation
# without requiring Docker or Podman.
{ lib, ... }:
{
  config.perSystem =
    { lib, ... }:
    {
      nix-lib.lib.oci.mkSandboxScript = {
        type = lib.types.functionTo lib.types.package;
        description = ''
          Generate a bubblewrap sandbox script for a container.

          Uses the container's `buildEnv` root filesystem with `/nix/store`
          bind-mounted read-only. Provides filesystem and PID isolation
          without requiring Docker or Podman.

          Defaults to an interactive bash shell. Pass arguments to run
          a specific command instead.
        '';
        file = "nix/modules/oci/lib/mkSandbox.nix";
        fn =
          {
            name,
            rootFilesystem,
            entrypoint ? [ ],
            environment ? { },
            user ? "root",
            isRoot ? true,
            workingDir ? null,
            pkgs,
          }:
          let
            # Include coreutils and bash in PATH for interactive exploration.
            # Container's /bin takes precedence (listed first).
            sandboxPath = "/bin:${pkgs.coreutils}/bin:${pkgs.bashInteractive}/bin";

            envFlags = lib.concatStringsSep " \\\n    " (
              [ "--setenv PATH ${lib.escapeShellArg sandboxPath}" ]
              ++ lib.mapAttrsToList (k: v: "--setenv ${lib.escapeShellArg k} ${lib.escapeShellArg v}") environment
            );

            homeDir = if isRoot then "/root" else "/home/${user}";

            userFlags = if isRoot then "--uid 0 --gid 0" else "--unshare-user --uid 4000 --gid 4000";

            workDirFlag = lib.optionalString (workingDir != null) "--chdir ${lib.escapeShellArg workingDir}";

            shellCmd = "${pkgs.bashInteractive}/bin/bash";
          in
          pkgs.writeShellScriptBin "oci-sandbox-${name}" ''
            set -euo pipefail
            root="${rootFilesystem}"

            if [ $# -gt 0 ]; then
              cmd=("$@")
            else
              cmd=("${shellCmd}")
            fi

            # Copy home directory to a writable tmpdir so tools like starship,
            # git, bash history, etc. can write to ~/.cache, ~/.local, etc.
            # The source is a Nix store path (read-only); the copy is writable.
            sandbox_home=$(mktemp -d)
            trap 'rm -rf "$sandbox_home"' EXIT
            if [ -d "$root/home" ]; then
              ${pkgs.coreutils}/bin/cp -rL "$root/home/." "$sandbox_home/" 2>/dev/null || true
              ${pkgs.coreutils}/bin/chmod -R u+w "$sandbox_home" 2>/dev/null || true
            fi
            # Same for /root when running as root
            sandbox_root=$(mktemp -d)
            trap 'rm -rf "$sandbox_home" "$sandbox_root"' EXIT
            if [ -d "$root/root" ]; then
              ${pkgs.coreutils}/bin/cp -rL "$root/root/." "$sandbox_root/" 2>/dev/null || true
              ${pkgs.coreutils}/bin/chmod -R u+w "$sandbox_root" 2>/dev/null || true
            fi

            exec ${pkgs.bubblewrap}/bin/bwrap \
              --ro-bind /nix/store /nix/store \
              --ro-bind "$root/bin" /bin \
              --ro-bind "$root/lib" /lib \
              --ro-bind "$root/etc" /etc \
              --bind "$sandbox_home" /home \
              --bind "$sandbox_root" /root \
              --bind-try "$root/var" /var \
              --tmpfs /tmp \
              --proc /proc \
              --dev /dev \
              --unshare-pid \
              --die-with-parent \
              --clearenv \
              ${envFlags} \
              --setenv HOME "${homeDir}" \
              --setenv USER "${user}" \
              --setenv TERM "''${TERM:-xterm}" \
              ${userFlags} \
              ${workDirFlag} \
              "''${cmd[@]}"
          '';
      };
    };
}
