{ lib, ... }:
{
  options.oci.container.hardening.landlock = lib.mkOption {
    type = lib.types.submodule {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable Landlock LSM restrictions.";
        };
        allowedReadPaths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Filesystem paths allowed for reading.";
        };
        allowedWritePaths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Filesystem paths allowed for writing.";
        };
        allowedExecutePaths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Filesystem paths allowed for execution.";
        };
        allowedTcpConnect = lib.mkOption {
          type = lib.types.listOf lib.types.port;
          default = [ ];
          description = "TCP ports allowed for outgoing connections.";
        };
        allowedTcpBind = lib.mkOption {
          type = lib.types.listOf lib.types.port;
          default = [ ];
          description = "TCP ports allowed for binding.";
        };
      };
    };
    default = { };
    description = "Landlock LSM access control configuration.";
  };
}
