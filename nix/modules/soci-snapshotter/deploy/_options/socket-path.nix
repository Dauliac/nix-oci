# services.soci-snapshotter.socketPath — gRPC socket for the daemon.
{ lib, ... }:
{
  options.services.soci-snapshotter.socketPath = lib.mkOption {
    type = lib.types.str;
    default = "/run/soci-snapshotter-grpc/soci-snapshotter-grpc.sock";
    description = ''
      Unix socket path where the SOCI snapshotter gRPC daemon listens.
      containerd connects to this path via its proxy_plugins configuration.
    '';
  };
}
