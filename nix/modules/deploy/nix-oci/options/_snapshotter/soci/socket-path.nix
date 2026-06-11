# oci.snapshotter.soci.socketPath — gRPC socket for the SOCI snapshotter.
{ lib, ... }:
{
  options.soci.socketPath = lib.mkOption {
    type = lib.types.str;
    default = "/run/soci-snapshotter-grpc/soci-snapshotter-grpc.sock";
    description = ''
      Unix socket path where the SOCI snapshotter listens.
      containerd connects to this path via its proxy_plugins configuration.
    '';
  };
}
