# Shared: NixOS service to derive entrypoint from.
#
# When set, nix-oci extracts the container entrypoint, stop signal,
# working directory, health check, and volume declarations from the
# NixOS service's systemd unit configuration.
{ lib, ... }:
{
  options.mainService = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = ''
      Logical NixOS service name to extract container metadata from.

      When set, nix-oci automatically derives:
      - **Entrypoint** from the systemd `ExecStart`
      - **Stop signal** from the systemd `KillSignal` or service adapter
      - **Working directory** from `WorkingDirectory` or service `dataDir`
      - **Health check** from the service adapter (curl, pg_isready, etc.)
      - **Volumes** from `StateDirectory`, `RuntimeDirectory`, etc.

      For most services, this matches the NixOS option prefix
      (e.g. `"nginx"` for `services.nginx`). For multi-instance services
      (e.g. Redis), the service adapter resolves the actual systemd
      unit name automatically.

      Requires `nixosConfig.modules` to include the service configuration.
    '';
    example = "nginx";
  };
}
