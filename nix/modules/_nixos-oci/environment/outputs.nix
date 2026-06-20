# Environment: SSL, nsswitch, env vars -- config, lib, and outputs
#
# Central collector for container environment variables and /etc files.
# Uses NixOS-native routing:
#   - Reads env vars from config.environment.variables (set by perf/gpu/nix modules)
#   - Reads /etc files from oci.container.includedEtcFiles (set by modules that declare etc)
#   - Still reads user-provided oci.container.environment for explicit vars
{
  config,
  lib,
  pkgs,
  ...
}:
let
  ociLib = import ../../../lib/oci.nix { inherit lib; };
in
{
  options.oci.lib.mkEtcDerivation = lib.mkOption {
    type = lib.types.unspecified;
    internal = true;
    readOnly = true;
    description = "Create a derivation from a NixOS environment.etc entry.";
    default = name: entry: ociLib.mkEtcDerivation { inherit name entry pkgs; };
  };

  options.oci.container._output.etcFiles = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    internal = true;
    readOnly = true;
    description = "Extracted /etc file derivations from includedEtcFiles.";
    default =
      let
        etc = config.environment.etc;
        # Runtime-overridden paths (resolv.conf, hostname, hosts) are excluded
        # because container runtimes always bind-mount them at startup.
        runtimeOverridden = config.oci.container.runtimeOverriddenEtcNames;
        wantedNames = builtins.filter (
          n: etc ? ${n} && !builtins.elem n runtimeOverridden
        ) config.oci.container.includedEtcFiles;
      in
      map (name: config.oci.lib.mkEtcDerivation name etc.${name}) wantedNames;
  };

  options.oci.container._output.envVars = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    internal = true;
    readOnly = true;
    description = "Container environment variables as KEY=VALUE strings.";
    default =
      let
        cfg = config.oci.container;
        home = config.oci.lib.homeDir;
        basePath = if cfg.fromImageEnabled then "/bin:/usr/local/bin:/usr/bin:/usr/sbin:/sbin" else "/bin";
        path =
          if cfg.installNix or false then
            "${basePath}:${home}/.nix-profile/bin:/nix/var/nix/profiles/default/bin"
          else
            basePath;
        skipTls = cfg.hardening.noTlsTrustStore or false;

        # NixOS environment.variables — set by perf, gpu, nix-support, and other modules
        nixosEnvVars = config.environment.variables or { };
      in
      # Core identity vars (always present, not overridable via environment.variables)
      [
        "PATH=${path}"
        "USER=${cfg.user}"
        "HOME=${home}"
      ]
      ++ lib.optionals (!skipTls) [
        "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      ]
      ++ lib.optionals (cfg.installNix or false) [
        "LANG=C.UTF-8"
        "LC_ALL=C.UTF-8"
        "NIX_PAGER=cat"
      ]
      # NixOS-native env vars (from perf, gpu, nix-support modules)
      # Filter out vars that are already set above to avoid duplicates
      ++ lib.mapAttrsToList (k: v: "${k}=${toString v}") (
        builtins.removeAttrs nixosEnvVars [
          "PATH"
          "USER"
          "HOME"
          "SSL_CERT_FILE"
          "LANG"
          "LC_ALL"
          "NIX_PAGER"
        ]
      )
      # GPU env vars now flow through environment.variables (above)
      # User-provided env vars (highest priority, last wins)
      ++ lib.mapAttrsToList (k: v: "${k}=${v}") cfg.environment;
  };

  config = {
    assertions =
      let
        cfg = config.oci.container;
        userEnv = cfg.environment;
        reservedVars = [
          "PATH"
          "HOME"
          "USER"
          "SSL_CERT_FILE"
        ];
        overriddenVars = builtins.filter (v: userEnv ? ${v}) reservedVars;
      in
      lib.optional (overriddenVars != [ ]) {
        assertion = false;
        message = ''
          nix-oci: `environment` overrides auto-derived variable(s): ${lib.concatStringsSep ", " overriddenVars}.
          nix-oci automatically sets these from container identity and config:
            - PATH: derived from fromImage, installNix, and /bin
            - HOME: derived from user (isRoot → /root, else /home/<user>)
            - USER: derived from container user name
            - SSL_CERT_FILE: always /etc/ssl/certs/ca-bundle.crt
          Your values will silently replace the auto-derived ones, which may
          break the container. If you need custom values, verify they include
          the expected defaults.
        '';
      };

    # SSL cert -- set via NixOS-native environment.variables
    environment.variables.SSL_CERT_FILE = lib.mkDefault "/etc/ssl/certs/ca-bundle.crt";
    environment.etc."ssl/certs/ca-bundle.crt".source =
      lib.mkDefault "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    environment.etc."nsswitch.conf".text = lib.mkDefault ''
      passwd:    files
      group:     files
      shadow:    files
      hosts:     files dns
      networks:  files
      ethers:    files
      services:  files
      protocols: files
      rpc:       files
    '';

    # Register default /etc files for inclusion
    oci.container.includedEtcFiles = [
      "nsswitch.conf"
    ]
    ++ lib.optionals (!(config.oci.container.hardening.noTlsTrustStore or false)) [
      "ssl/certs/ca-bundle.crt"
    ];
  };
}
