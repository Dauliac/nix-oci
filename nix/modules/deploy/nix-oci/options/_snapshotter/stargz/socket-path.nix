# oci.snapshotter.stargz.socketPath — gRPC socket for the stargz snapshotter.
{ lib, ... }:
{
  options.stargz.socketPath = lib.mkOption {
    type = lib.types.str;
    default = "/run/containerd-stargz-grpc/containerd-stargz-grpc.sock";
    description = ''
      Unix socket path where the stargz snapshotter listens.
      containerd connects to this path via its proxy_plugins configuration.
    '';
  };
}
