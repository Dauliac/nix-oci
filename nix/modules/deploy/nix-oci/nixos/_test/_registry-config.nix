# NixOS config: local Docker registry for integration testing.
{ lib, ... }:
{
  services.dockerRegistry = {
    enable = lib.mkDefault true;
    port = lib.mkDefault 5000;
  };

  # Silence distribution/registry v3's built-in OpenTelemetry exporter.
  # Without this, the registry retries `POST https://localhost:4318/v1/traces`
  # every 10 s in the test VM (no collector runs there), which spams the
  # journal and blocks registry ops on the OTLP round-trip timeout. The
  # standard OTel-SDK env-var switch disables all exporters cleanly.
  systemd.services.docker-registry.environment = {
    OTEL_SDK_DISABLED = "true";
    OTEL_TRACES_EXPORTER = "none";
    OTEL_METRICS_EXPORTER = "none";
    OTEL_LOGS_EXPORTER = "none";
  };
}
