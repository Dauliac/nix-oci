# Environment: SSL, nsswitch, env vars — config, lib, and outputs
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
        wantedNames = builtins.filter (n: etc ? ${n}) [
          "nsswitch.conf"
          "ssl/certs/ca-bundle.crt"
        ];
      in
      map (name: config.oci.lib.mkEtcDerivation name etc.${name}) wantedNames;
  };

  options.oci.container._output.envVars = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    internal = true;
    readOnly = true;
    description = "Container environment variables as KEY=VALUE strings.";
    default = [
      "PATH=/bin"
      "USER=${config.oci.container.user}"
      "HOME=${config.oci.lib.homeDir}"
      "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
    ];
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
