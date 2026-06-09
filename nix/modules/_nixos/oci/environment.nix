# Environment: SSL, nsswitch, env vars -- config, lib, and outputs
{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.oci.lib.mkEtcDerivation = lib.mkOption {
    type = lib.types.unspecified;
    internal = true;
    readOnly = true;
    description = "Create a derivation from a NixOS environment.etc entry.";
    default =
      name: entry:
      let
        safeName = builtins.replaceStrings [ "/" ] [ "-" ] name;
        mode = entry.mode or "0644";
        isSymlink = mode == "symlink" || mode == "direct-symlink";
      in
      pkgs.runCommand "etc-${safeName}" { } ''
        mkdir -p $out/etc/$(dirname "${name}")
        cp -L ${entry.source} $out/etc/${name}
        ${if isSymlink then "" else "chmod ${mode} $out/etc/${name}"}
      '';
  };

  options.oci.container._output.etcFiles = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    internal = true;
    readOnly = true;
    description = "Extracted /etc file derivations (nsswitch, SSL certs).";
    default =
      let
        etc = config.environment.etc;
        # Runtime-overridden paths (resolv.conf, hostname, hosts) are excluded
        # because container runtimes always bind-mount them at startup.
        runtimeOverridden = config.oci.container.runtimeOverriddenEtcNames;
        wantedNames = builtins.filter (n: etc ? ${n} && !builtins.elem n runtimeOverridden) [
          "nsswitch.conf"
          "ssl/certs/ca-bundle.crt"
          "nix/nix.conf"
        ];
      in
      map (name: config.oci.lib.mkEtcDerivation name etc.${name}) wantedNames;
  };

  options.oci.container.environment = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    description = "User-provided environment variables forwarded from the flake-parts container options.";
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
        basePath = "/bin";
        path =
          if cfg.installNix or false then
            "${basePath}:${home}/.nix-profile/bin:/nix/var/nix/profiles/default/bin"
          else
            basePath;
      in
      [
        "PATH=${path}"
        "USER=${cfg.user}"
        "HOME=${home}"
        "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      ]
      ++ lib.optionals (cfg.installNix or false) [
        "LANG=C.UTF-8"
        "LC_ALL=C.UTF-8"
        "NIX_PAGER=cat"
      ]
      ++ (cfg._output.performance.envVars or [ ])
      ++ lib.mapAttrsToList (k: v: "${k}=${v}") cfg.environment;
  };

  config = {
    environment.variables.SSL_CERT_FILE = "/etc/ssl/certs/ca-bundle.crt";
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
  };
}
