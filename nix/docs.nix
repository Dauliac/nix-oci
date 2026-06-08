# Documentation build module (docs partition only)
#
# Builds an NDG site with:
# - Module options (flake-parts, deploy, NixOS container)
# - Markdown content pages
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
        ndg = inputs.ndg.packages.${system}.ndg;
        import-tree = inputs.import-tree;

        # --- Flake-parts options (oci.*) ---
        flakePartsEval =
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

        perSystemOptions = flakePartsEval.options.perSystem.type.getSubOptions [ ];

        # Rewrite /nix/store/<hash>-source/path -> clickable GitHub link
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

        # Top-level oci options
        topLevelDoc = pkgs.nixosOptionsDoc {
          options = {
            inherit (flakePartsEval.options) oci;
          };
          transformOptions = cleanupOptions;
        };

        # Per-system oci options
        perSystemDoc = pkgs.nixosOptionsDoc {
          options = {
            inherit (perSystemOptions) oci;
          };
          transformOptions = cleanupOptions;
        };

        # Container sub-options (from the deferred module)
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

        # --- Deploy module options (services.nix-oci.*) ---
        # Extract the composed NixOS deploy module from the flake-parts eval,
        # then evaluate it standalone to get its options.
        deployNixosModule = flakePartsEval.config.flake.modules.nixos.nix-oci;

        deployEval = lib.evalModules {
          modules = [
            deployNixosModule
            {
              options._module.args = lib.mkOption { internal = true; };
              config._module.check = false;
            }
          ];
        };

        deployDoc = pkgs.nixosOptionsDoc {
          options = {
            inherit (deployEval.options) services;
          };
          transformOptions = cleanupOptions;
        };

        # --- NixOS container module options (oci.container.*) ---
        # Use import-tree to discover _nixos/oci modules, same as eval.nix does.
        ociNixOSModule = import-tree ./modules/_nixos/oci;

        nixosContainerEval = lib.evalModules {
          modules = [
            ociNixOSModule
            {
              options._module.args = lib.mkOption { internal = true; };
              config._module = {
                check = false;
                args = {
                  pkgs = lib.modules.mkForce pkgs;
                };
              };
            }
          ];
        };

        nixosContainerDoc = pkgs.nixosOptionsDoc {
          options = {
            inherit (nixosContainerEval.options) oci;
          };
          transformOptions = cleanupOptions;
        };

        # --- Merged options JSON for NDG sidebar ---
        mergedOptionsJSON = pkgs.runCommand "merged-options.json" {
          nativeBuildInputs = [ pkgs.jq ];
        } ''
          jq -s '.[0] * .[1] * .[2] * .[3] * .[4]' \
            ${topLevelDoc.optionsJSON}/share/doc/nixos/options.json \
            ${perSystemDoc.optionsJSON}/share/doc/nixos/options.json \
            ${containerDoc.optionsJSON}/share/doc/nixos/options.json \
            ${deployDoc.optionsJSON}/share/doc/nixos/options.json \
            ${nixosContainerDoc.optionsJSON}/share/doc/nixos/options.json \
            > $out
        '';

        # --- Build the input directory ---
        docsInputDir = pkgs.runCommand "ndg-input" { } ''
          mkdir -p $out/examples

          # Copy static content pages
          cp -r ${../docs/content}/* $out/

          # Generate options reference pages
          {
            echo '+++'
            echo 'title = "Flake-Parts Options (Top-level)"'
            echo 'description = "Options set at the flake level"'
            echo '+++'
            echo ""
            echo "# Flake-Parts Options (Top-level)"
            echo ""
            echo "These options are set at the flake level (outside \`perSystem\`)."
            echo ""
            cat ${topLevelDoc.optionsCommonMark}
          } > $out/options-toplevel.md

          {
            echo '+++'
            echo 'title = "Flake-Parts Options (Per-System)"'
            echo 'description = "Options set inside perSystem"'
            echo '+++'
            echo ""
            echo "# Flake-Parts Options (Per-System)"
            echo ""
            echo "These options are set inside \`perSystem\`."
            echo ""
            cat ${perSystemDoc.optionsCommonMark}
          } > $out/options-persystem.md

          {
            echo '+++'
            echo 'title = "Container Options"'
            echo 'description = "Options on each oci.containers.<name>"'
            echo '+++'
            echo ""
            echo "# Container Options"
            echo ""
            echo "These options are available on each container defined in \`oci.containers.<name>\`."
            echo ""
            cat ${containerDoc.optionsCommonMark}
          } > $out/options-container.md

          {
            echo '+++'
            echo 'title = "Deploy Module Options"'
            echo 'description = "services.nix-oci.* options for NixOS and Home Manager"'
            echo '+++'
            echo ""
            echo "# Deploy Module Options"
            echo ""
            echo "These options are available under \`services.nix-oci.*\` in both NixOS and Home Manager modules."
            echo ""
            cat ${deployDoc.optionsCommonMark}
          } > $out/options-deploy.md

          {
            echo '+++'
            echo 'title = "NixOS Container Module Options"'
            echo 'description = "oci.container.* options inside nixosConfig"'
            echo '+++'
            echo ""
            echo "# NixOS Container Module Options"
            echo ""
            echo "These options are available inside \`nixosConfig.modules\` under the \`oci.container.*\` namespace."
            echo ""
            cat ${nixosContainerDoc.optionsCommonMark}
          } > $out/options-nixos-container.md

          # Convert examples to markdown
          for f in $(find ${../examples} -name '*.nix' -type f | sort); do
            relpath="''${f#${../examples}/}"
            name="''${relpath%.nix}"
            safe_name="$(echo "$name" | tr '/' '-')"
            title="$(echo "$safe_name" | tr '-' ' ')"

            {
              echo "+++"
              echo "title = \"$title\""
              echo "+++"
              echo ""
              echo "# $title"
              echo ""
              echo '```nix'
              cat "$f"
              echo '```'
            } > "$out/examples/$safe_name.md"
          done

          # Generate examples index
          {
            echo '+++'
            echo 'title = "Examples"'
            echo 'description = "Example configurations"'
            echo '+++'
            echo ""
            echo "# Examples"
            echo ""
            for f in $(find $out/examples -name '*.md' -type f | sort); do
              name="$(basename "$f" .md)"
              title="$(echo "$name" | tr '-' ' ')"
              echo "- [$title](./examples/$name.md)"
            done
          } > $out/examples-index.md
        '';

        # --- NDG site build (using CLI directly) ---
        ndgConfig = pkgs.writers.writeTOML "ndg.toml" {
          title = "nix-oci";
          input_dir = "${docsInputDir}";
          output_dir = placeholder "out";
          module_options = "${mergedOptionsJSON}";
          search.enable = true;
          highlight_code = true;
          sidebar.options.depth = 3;
        };

        docs = pkgs.runCommandLocal "nix-oci-docs" {
          nativeBuildInputs = [ ndg ];
        } ''
          ndg --config-file "${ndgConfig}" --verbose html \
            --jobs $NIX_BUILD_CORES --output-dir "$out"
        '';
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
