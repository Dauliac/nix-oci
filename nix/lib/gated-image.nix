# Pure function to create a gated OCI image.
#
# Wraps a raw nix2container image so that its check dependencies must
# succeed before the image can be used. The gate derivation is a thin
# wrapper — a text file that references the raw image path. Building
# it forces all check derivations to complete first.
#
# The returned attrset preserves the raw image's passthru (copyToRegistry,
# copyToPodman, imageName, imageTag, etc.) so downstream consumers work
# transparently. The only addition is a `.gate` attribute pointing to
# the gate derivation — deploy modules build the gate before loading.
#
# No archive is stored in the Nix store — checks use mkTransientArchive
# internally to create ephemeral archives that are discarded after use.
{ lib }:
{
  # Create a gated image.
  #
  # Arguments:
  #   pkgs         - nixpkgs package set
  #   rawImage     - the nix2container image derivation
  #   checks       - list of check derivations that must pass
  #   name         - container name (for derivation naming)
  #
  # Returns: the raw image attrset with an added `.gate` derivation.
  # Consumers that want enforcement should build `.gate` before using the image.
  mkGatedImage =
    {
      pkgs,
      rawImage,
      checks,
      name,
    }:
    if checks == [ ] then
      rawImage
    else
      rawImage
      // {
        gate =
          pkgs.runCommandLocal "oci-gate-${name}"
            {
              nativeBuildInputs = checks;
            }
            ''
              echo "All checks passed for ${name}" > $out
              echo "image: ${rawImage}" >> $out
            '';
      };
}
