{ lib, ... }:
{
  options.signing.cosign.keyEnvVar = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = "COSIGN_KEY";
    description = ''
      Environment variable consulted at runtime for the cosign key
      path or URI.  When set in the environment, its value is used as
      `--key <value>`, overriding the Nix-configured `key` option.

      Set to `null` to disable runtime override and always use the
      Nix-configured `key` value.

      Only relevant when `keyless` is false.

      The default `"COSIGN_KEY"` matches cosign's own convention.
      Common patterns:
        - `COSIGN_KEY=./cosign.key`              — local file
        - `COSIGN_KEY=env://COSIGN_PRIVATE_KEY`  — key content in another env var
        - `COSIGN_KEY=awskms://...`              — KMS URI
    '';
  };
}
