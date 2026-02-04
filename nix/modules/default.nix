# Main modules entry point
# Lists all modules for flake-module.nix (external users without import-tree)
{ ... }:
{
  imports = [
    # Flake outputs
    ./flake/apps.nix
    ./flake/checks.nix
    ./flake/packages.nix

    # OCI core options (one file per option)
    ./oci/enabled.nix
    ./oci/enableFlakeOutputs.nix
    ./oci/devShellPackage.nix
    ./oci/enableDevShell.nix
    ./oci/rootPath.nix
    ./oci/fromImageManifestRootPath.nix
    ./oci/registry.nix

    # OCI outputs (intermediate options)
    ./oci/outputs/apps.nix
    ./oci/outputs/packages.nix
    ./oci/outputs/checks.nix

    # OCI lib - pure flake-level helpers
    ./oci/lib/ociMkOCIName.nix
    ./oci/lib/ociMkOCITag.nix
    ./oci/lib/ociMkOCIUser.nix
    ./oci/lib/ociMkOCIEntrypoint.nix
    ./oci/lib/ociPrefixOutputs.nix
    ./oci/lib/ociFilterEnabledOutputsSet.nix
    ./oci/lib/ociMkOCIPulledManifestLockPath.nix
    ./oci/lib/ociMkOCIPulledManifestLockRelativeRootPath.nix
    ./oci/lib/ociMkOCIPulledManifestLockRelativePath.nix

    # OCI lib - perSystem builders
    ./oci/lib/mkRootShadowSetup.nix
    ./oci/lib/mkNonRootShadowSetup.nix
    ./oci/lib/mkNixShadowSetup.nix
    ./oci/lib/mkRoot.nix
    ./oci/lib/mkNixConfig.nix
    ./oci/lib/mkPodmanPolicy.nix
    ./oci/lib/mkSimpleOCI.nix
    ./oci/lib/mkNixOCI.nix
    ./oci/lib/mkNixOCILayer.nix
    ./oci/lib/mkNixOrSimpleOCI.nix
    ./oci/lib/mkDebugOCI.nix
    ./oci/lib/mkOCI.nix
    ./oci/lib/mkDockerArchive.nix
    ./oci/lib/mkPerContainerOption.nix

    # OCI containers - perContainer base and individual options
    ./oci/containers/perContainer.nix
    ./oci/containers/rootPath.nix
    ./oci/containers/tag.nix
    ./oci/containers/tags.nix
    ./oci/containers/name.nix
    ./oci/containers/registry.nix
    ./oci/containers/user.nix
    ./oci/containers/package.nix
    ./oci/containers/dependencies.nix
    ./oci/containers/entrypoint.nix
    ./oci/containers/isRoot.nix
    ./oci/containers/installNix.nix
    ./oci/containers/push.nix

    # OCI containers - multiArch options
    ./oci/containers/multiArch/enabled.nix
    ./oci/containers/multiArch/tempTagPrefix.nix

    # OCI containers - fromImage options
    ./oci/containers/fromImage/enabled.nix
    ./oci/containers/fromImage/imageName.nix
    ./oci/containers/fromImage/imageTag.nix
    ./oci/containers/fromImage/os.nix
    ./oci/containers/fromImage/arch.nix

    # OCI containers - debug options
    ./oci/containers/debug/enabled.nix
    ./oci/containers/debug/packages.nix
    ./oci/containers/debug/entrypoint/enabled.nix
    ./oci/containers/debug/entrypoint/wrapper.nix

    # OCI containers - cve options
    ./oci/containers/cve/rootPath.nix
    ./oci/containers/cve/trivy/enabled.nix
    ./oci/containers/cve/trivy/ignore/fileEnabled.nix
    ./oci/containers/cve/trivy/ignore/path.nix
    ./oci/containers/cve/trivy/ignore/extra.nix
    ./oci/containers/cve/grype/enabled.nix
    ./oci/containers/cve/grype/config/enabled.nix
    ./oci/containers/cve/grype/config/path.nix

    # OCI containers - sbom options
    ./oci/containers/sbom/rootPath.nix
    ./oci/containers/sbom/syft/enabled.nix
    ./oci/containers/sbom/syft/config/enabled.nix
    ./oci/containers/sbom/syft/config/path.nix

    # OCI containers - credentialsLeak options
    ./oci/containers/credentialsLeak/trivy/enabled.nix

    # OCI containers - test options
    ./oci/containers/test/rootPath.nix
    ./oci/containers/test/dive/enabled.nix
    ./oci/containers/test/containerStructureTest/enabled.nix
    ./oci/containers/test/containerStructureTest/configs.nix
    ./oci/containers/test/dgoss/enabled.nix
    ./oci/containers/test/dgoss/optionsPath.nix

    # OCI debug
    ./oci/debug/options.nix

    # OCI security
    ./oci/security/cve/options.nix
    ./oci/security/cve/lib.nix
    ./oci/security/sbom/options.nix
    ./oci/security/sbom/lib.nix
    ./oci/security/credentials-leak/options.nix
    ./oci/security/credentials-leak/lib.nix

    # OCI testing
    ./oci/testing/options.nix
    ./oci/testing/dive/lib.nix
    ./oci/testing/dgoss/lib.nix
    ./oci/testing/container-structure/lib.nix

    # OCI manifest & multi-arch
    ./oci/manifest/lib.nix
    ./oci/multi-arch/lib.nix

    # OCI podman
    ./oci/podman/lib.nix

    # OCI packages (one file per package)
    ./oci/packages/skopeo.nix
    ./oci/packages/nix2container.nix
    ./oci/packages/containerStructureTest.nix
    ./oci/packages/podman.nix
    ./oci/packages/grype.nix
    ./oci/packages/syft.nix
    ./oci/packages/trivy.nix
    ./oci/packages/dive.nix
    ./oci/packages/dgoss.nix
    ./oci/packages/skaffold.nix
    ./oci/packages/regctl.nix

    # OCI internal outputs
    ./oci/internal/packages.nix
    ./oci/internal/apps.nix
    ./oci/internal/checks.nix
    ./oci/internal/dev-shell.nix
  ];
}
