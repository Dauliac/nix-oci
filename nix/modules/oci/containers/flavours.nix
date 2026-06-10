# Container flavours - variant image definitions
#
# Each flavour is a deferred NixOS module that gets evaluated in a synthetic
# container alongside a parent-inheritance module. The flavour module has
# full access to the same options as a regular container.
#
# Merge semantics (handled by the expansion module):
#   - List options (modules, dependencies, ports): parent ++ flavour (additive)
#   - Attrset options (environment, labels): parent // flavour (merge)
#   - Scalar options (package, tag, isRoot): parent mkDefault, flavour overrides
#
# Example:
#   oci.containers.nginx = {
#     nixosConfig.mainService = "nginx";
#     flavours.debug = {
#       dependencies = with pkgs; [ strace curl bash ];
#       nixosConfig.modules = [
#         ({ ... }: { services.nginx.appendConfig = "error_log stderr debug;"; })
#       ];
#     };
#   };
{ lib, ... }:
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          options.flavours = lib.mkOption {
            type = lib.types.attrsOf lib.types.deferredModule;
            default = { };
            description = ''
              Variant image definitions. Each flavour is a module evaluated
              in a synthetic container that inherits from the parent.

              List options (dependencies, nixosConfig.modules, homeConfig.modules,
              ports, etc.) are additive — the flavour's values are appended to
              the parent's. Scalar options (package, tag, isRoot, etc.) inherit
              from the parent via mkDefault and can be overridden.
            '';
            example = lib.literalExpression ''
              {
                debug = {
                  dependencies = with pkgs; [ strace curl coreutils ];
                };
                slim = {
                  hardening.noTlsTrustStore = true;
                  hardening.disableDns = true;
                };
              }
            '';
          };
        };
    };
}
