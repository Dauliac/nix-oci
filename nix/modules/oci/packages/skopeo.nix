# OCI packages - skopeo
{
  lib,
  flake-parts-lib,
  inputs,
  ...
}:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    {
      system,
      pkgs,
      ...
    }:
    let
      # The upstream nix2container skopeo-nix2container package patches skopeo
      # to add a "nix" transport. However, our nixpkgs ships skopeo >= 1.20
      # which migrated from go.podman.io/image/v5 to
      # github.com/containers/image/v5, breaking the upstream patch.
      # We override preBuild to use the correct vendor path.
      skopeo-nix2container-fixed =
        inputs.nix2container.packages.${system}.skopeo-nix2container.overrideAttrs
          (old: {
            preBuild =
              let
                nix2containerSrc = inputs.nix2container.packages.${system}.nix2container-bin.src;
                # The upstream patch targets go.podman.io/image/v5 but our skopeo
                # vendors github.com/containers/image/v5 instead.
                rawPatch = pkgs.fetchpatch2 {
                  url = "https://github.com/nlewo/container-libs/commit/21b053ac62f3137de42585611953e923577d0e10.patch";
                  sha256 = "sha256-pfwQh7FKWHY/xVAGMSvnjMOmkpMo9NG2HFZqhqZ1VN0=";
                  postFetch = ''
                    sed -i \
                      -e '/^index /d' \
                      -e '/^similarity index /d' \
                      -e '/^dissimilarity index /d' \
                      $out
                  '';
                };
                fixedPatch = pkgs.runCommand "skopeo-nix-transport.patch" { } ''
                  sed 's|go\.podman\.io/image/v5|github.com/containers/image/v5|g' \
                    ${rawPatch} > $out
                '';
              in
              ''
                mkdir -p vendor/github.com/nlewo/nix2container/
                cp -r ${nix2containerSrc}/* vendor/github.com/nlewo/nix2container/
                chmod -R u+w vendor/github.com/nlewo/nix2container/
                # Fix nix2container source imports for the new module path
                find vendor/github.com/nlewo/nix2container/ -name '*.go' -exec \
                  sed -i 's|go\.podman\.io/image/v5|github.com/containers/image/v5|g' {} +
                cd vendor/github.com/containers/image/v5
                mkdir -p nix/
                touch nix/transport.go
                cat ${fixedPatch} | patch -p2
                cd -

                # Go checks packages in the vendor directory are declared in the modules.txt file.
                echo '# github.com/nlewo/nix2container v1.0.0' >> vendor/modules.txt
                echo '## explicit; go 1.13' >> vendor/modules.txt
                echo github.com/nlewo/nix2container/nix >> vendor/modules.txt
                echo github.com/nlewo/nix2container/types >> vendor/modules.txt
                echo github.com/containers/image/v5/nix >> vendor/modules.txt
                # All packages declared in the modules.txt file must also be required by the go.mod file.
                echo 'require (' >> go.mod
                echo '  github.com/nlewo/nix2container v1.0.0' >> go.mod
                echo ')' >> go.mod
              '';
          });
    in
    {
      options.oci.packages.skopeo = lib.mkOption rec {
        type = lib.types.package;
        description = "The package to use for skopeo.";
        default = skopeo-nix2container-fixed;
        defaultText = lib.literalExpression "inputs.nix2container.packages.\${system}.skopeo-nix2container";
        example = defaultText;
      };
    }
  );
}
