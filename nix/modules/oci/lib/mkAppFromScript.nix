# Factory: generate a flake app wrapper from a mkScript-style function.
#
# Eliminates the repetitive mkApp* pattern found in 15+ lib files.
# Instead of writing a separate mkApp for each tool, use:
#
#   mkAppFoo = ociLib.mkAppFromScript {
#     name = "foo";
#     mkScript = ociLib.mkScriptFoo;
#     file = "path/to/lib.nix";
#   };
{ ... }:
{
  config.perSystem =
    { lib, ... }:
    {
      nix-lib.lib.oci.mkAppFromScript = {
        type = lib.types.functionTo lib.types.attrs;
        description = ''
          Factory: create a flake app wrapper from a mkScript function.

          Given a mkScript function and its arguments, returns a nix-lib entry
          (with type, description, file, fn) that produces `{ type = "app"; program = ...; }`.
        '';
        file = "nix/modules/oci/lib/mkAppFromScript.nix";
        fn =
          {
            # Human-readable tool name (e.g. "Trivy CVE scanning")
            description,
            # Source file path for nix-lib metadata
            file,
            # The mkScript function to wrap (e.g. ociLib.mkScriptCVETrivy)
            mkScript,
            # Binary name prefix (e.g. "trivy" → "trivy-${containerId}")
            scriptPrefix,
          }:
          {
            type = lib.types.functionTo lib.types.attrs;
            description = "Create flake app for ${description}";
            inherit file;
            fn = args: {
              type = "app";
              program = "${mkScript args}/bin/${scriptPrefix}-${args.containerId}";
            };
          };
      };
    };
}
