# Documentation build module (docs partition only)
#
# Builds an mdbook site with:
# - README as introduction
# - Module options extracted via nixosOptionsDoc
# - Examples from the examples/ directory
# - GitHub Actions workflow for Pages deployment
{
  inputs,
  lib,
  ...
}:
{
  config = {
    perSystem =
      {
        config,
        pkgs,
        system,
        ...
      }:
      let
        # Evaluate the OCI flake module in isolation to extract option declarations
        eval =
          inputs.flake-parts.lib.evalFlakeModule
            {
              inputs = inputs // {
                self = { };
              };
            }
            {
              imports = [
                (import ./flake-module.nix inputs)
              ];
              systems = [ system ];
            };

        perSystemOptions = eval.options.perSystem.type.getSubOptions [ ];

        # Rewrite /nix/store/<hash>-source/path → clickable GitHub link
        repoUrl = "https://github.com/Dauliac/nix-oci/blob/main";
        cleanupOptions =
          opt:
          let
            cleanDecl =
              decl:
              let
                declStr = toString decl;
                match = builtins.match "/nix/store/[a-z0-9]+-source/(.*)" declStr;
              in
              if match != null then
                let
                  raw = builtins.head match;
                  # Strip ", via option ..." suffixes from deferred module paths
                  parts = builtins.match "([^,]+),? ?(via .*)?" raw;
                  relPath = if parts != null then builtins.head parts else raw;
                in
                {
                  url = "${repoUrl}/${relPath}";
                  name = relPath;
                }
              else
                decl;
          in
          opt
          // {
            visible = (opt.visible or true) && !(opt.internal or false);
            declarations = map cleanDecl opt.declarations;
          };

        # Top-level oci options (oci.enabled, etc.)
        topLevelDoc = pkgs.nixosOptionsDoc {
          options = {
            inherit (eval.options) oci;
          };
          transformOptions = cleanupOptions;
        };

        # Per-system oci options (oci.containers.*, oci.packages.*, etc.)
        perSystemDoc = pkgs.nixosOptionsDoc {
          options = {
            inherit (perSystemOptions) oci;
          };
          transformOptions = cleanupOptions;
        };

        # Container sub-options (oci.containers.<name>.package, .tag, etc.)
        #
        # The `perContainer` option uses a deferredModuleWith pattern:
        # - getSubOptions on the deferred type only sees static modules
        # - The real options (package, tag, registry, ...) are contributed
        #   dynamically and only visible after apply creates a submoduleWith
        #
        # We access the resolved type from this partition's own config:
        # config.oci.perContainer IS the apply'd submoduleWith with all modules.
        # getSubOptions returns a lazy attrset; we remove perTag/tagConfigs
        # which have nested deferred modules that need containerConfig.
        containerSubOptions =
          let
            allOpts = config.oci.perContainer.getSubOptions [ ];
          in
          builtins.removeAttrs allOpts [
            "perTag"
            "tagConfigs"
            "_containerName"
            "_module"
          ];

        containerDoc = pkgs.nixosOptionsDoc {
          options = containerSubOptions;
          transformOptions = cleanupOptions;
        };

        docs = pkgs.stdenv.mkDerivation {
          name = "nix-oci-docs";
          src = lib.fileset.toSource {
            root = ../.;
            fileset = lib.fileset.unions [
              ../docs/book.toml
              ../README.md
              ../examples
            ];
          };
          nativeBuildInputs = [ pkgs.mdbook ];

          buildPhase = ''
            runHook preBuild

            mkdir -p docs/src/examples

            # Introduction from README
            cp README.md docs/src/introduction.md

            # Options reference pages
            {
              echo "# Top-level Options"
              echo ""
              echo "These options are set at the flake level."
              echo ""
              cat ${topLevelDoc.optionsCommonMark}
            } > docs/src/options-toplevel.md

            {
              echo "# Per-System Options"
              echo ""
              echo "These options are set inside \`perSystem\`."
              echo ""
              cat ${perSystemDoc.optionsCommonMark}
            } > docs/src/options-persystem.md

            {
              echo "# Container Options"
              echo ""
              echo "These options are available on each container defined in \`oci.containers.<name>\`."
              echo ""
              cat ${containerDoc.optionsCommonMark}
            } > docs/src/options-container.md

            # Convert examples to markdown and collect entries for SUMMARY
            example_entries=""
            for f in $(find examples -name '*.nix' -type f | sort); do
              relpath="''${f#examples/}"
              name="''${relpath%.nix}"
              safe_name="$(echo "$name" | tr '/' '-')"
              title="$(echo "$safe_name" | tr '-' ' ')"

              {
                echo "# $title"
                echo ""
                echo '```nix'
                cat "$f"
                echo '```'
              } > "docs/src/examples/$safe_name.md"

              example_entries="''${example_entries}  - [$title](./examples/$safe_name.md)
            "
            done

            # Generate SUMMARY.md
            {
              echo "# Summary"
              echo ""
              echo "- [Introduction](./introduction.md)"
              echo "- [Options Reference]()"
              echo "  - [Top-level Options](./options-toplevel.md)"
              echo "  - [Per-System Options](./options-persystem.md)"
              echo "  - [Container Options](./options-container.md)"
              echo "- [Examples]()"
              echo "$example_entries"
            } > docs/src/SUMMARY.md

            # Build the book
            mdbook build docs

            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            cp -r docs/book $out
            runHook postInstall
          '';
        };
      in
      {
        legacyPackages = {
          docs-github-workflows = config.githubActions.workflowsDir;
          inherit docs;
        };

        # GitHub Actions workflow for Pages deployment
        githubActions = {
          enable = true;

          workflows.deploy-docs = {
            name = "Deploy Documentation";

            on = {
              push.branches = [ "main" ];
              workflowDispatch = { };
            };

            permissions = {
              contents = "read";
              pages = "write";
              id-token = "write";
            };

            concurrency = {
              group = "pages";
              cancelInProgress = false;
            };

            jobs.build = {
              runsOn = "ubuntu-latest";
              steps = [
                {
                  name = "Checkout";
                  uses = "actions/checkout@v4";
                }
                {
                  name = "Install Nix";
                  uses = "DeterminateSystems/nix-installer-action@main";
                }
                {
                  name = "Cache Nix store";
                  uses = "DeterminateSystems/magic-nix-cache-action@main";
                }
                {
                  name = "Build documentation";
                  run = "nix build .#legacyPackages.x86_64-linux.docs";
                }
                {
                  name = "Upload artifact";
                  uses = "actions/upload-pages-artifact@v3";
                  with_ = {
                    path = "result";
                  };
                }
              ];
            };

            jobs.deploy = {
              runsOn = "ubuntu-latest";
              needs = [ "build" ];
              environment = {
                name = "github-pages";
                url = "\${{ steps.deployment.outputs.page_url }}";
              };
              steps = [
                {
                  id = "deployment";
                  name = "Deploy to GitHub Pages";
                  uses = "actions/deploy-pages@v4";
                }
              ];
            };
          };
        };
      };
  };
}
