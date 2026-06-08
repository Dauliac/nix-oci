# Per-container: whether to auto-start the container after loading.
{ lib, ... }:
{
  options.autoStart = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      When true, creates a runner service that starts the container
      after the image is loaded. The runner depends on the loader service.
    '';
  };
}
