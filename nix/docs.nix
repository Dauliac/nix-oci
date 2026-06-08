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
            "perArch"
            "archConfigs"
            "_containerName"
            "_module"
          ];

        containerDoc = pkgs.nixosOptionsDoc {
          options = containerSubOptions;
          transformOptions = cleanupOptions;
        };

        # --- Deploy module options (oci.*) ---
        # The deploy submodule imports shared options (_options/) + deploy extensions (_containers/).
        # We resolve import-tree here and provide nix2container + ociLib via specialArgs.
        sharedOptions = import-tree ./modules/oci/containers/_options;
        deployExtensions = import-tree ./modules/deploy/nix-oci/options/_containers;

        # Minimal ociLib stub for option declarations (only needed for default values)
        ociLib = {
          parseContainerPort = _: "";
          mkExposedPorts = _: { };
          parseHostPort = _: 0;
          mkShadowSetup = _: [ ];
          mkRoot = _: null;
        };

        deployOptionModules = [
          (
            { lib, ... }:
            {
              options.oci.enable = lib.mkEnableOption "nix-oci container deployment";
            }
          )
          (
            { lib, ... }:
            {
              options.oci.backend = lib.mkOption {
                type = lib.types.enum [
                  "docker"
                  "podman"
                ];
                default = "podman";
                description = "Container runtime backend to load and run images.";
              };
            }
          )
          (
            { lib, ... }:
            {
              options.oci.containers = lib.mkOption {
                type = lib.types.attrsOf (
                  lib.types.submoduleWith {
                    modules = [
                      sharedOptions
                      deployExtensions
                    ];
                    specialArgs = {
                      inherit pkgs ociLib;
                      nix2container =
                        inputs.nix2container.packages.${system}.nix2container;
                    };
                  }
                );
                default = { };
                description = ''
                  OCI containers to build, load, and optionally run.
                  Each entry builds an image via nix2container and creates
                  a systemd service to load it into the container runtime.
                '';
              };
            }
          )
        ];

        deployEval = lib.evalModules {
          modules = deployOptionModules ++ [
            {
              options._module.args = lib.mkOption { internal = true; };
              config._module.check = false;
            }
          ];
        };

        deployDoc = pkgs.nixosOptionsDoc {
          options = {
            inherit (deployEval.options) oci;
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

        # Diataxis layout with NDG group_by_dir:
        #   Root (flat): index.md (overview), getting-started.md (tutorial)
        #   ▼ How-to:    task-oriented guides
        #   ▼ Reference: markdown templates with <!-- OPTIONS:* --> markers replaced by generated content
        #   ▼ Examples:   all examples with [category] prefix
        docsInputDir = pkgs.runCommand "ndg-input" {
          nativeBuildInputs = [ pkgs.gnused ];
        } ''
          mkdir -p $out/{how-to,reference,examples}

          # Root pages (flat, top of sidebar)
          # README.md and CONTRIBUTING.md are the source of truth, copied here for NDG
          cp ${../README.md} $out/index.md
          cp ${../CONTRIBUTING.md} $out/contributing.md
          cp ${../docs/content}/getting-started.md $out/

          # --- How-to guides ---
          for f in ${../docs/content}/how-to/*.md; do
            [ "$(basename "$f")" = "index.md" ] && continue
            cp "$f" $out/how-to/
          done

          # --- Reference: copy templates and inject generated options at markers ---
          for f in ${../docs/content}/reference/*.md; do
            cp "$f" $out/reference/
          done
          chmod -R u+w $out/reference

          sed -i '/<!-- OPTIONS:toplevel -->/r ${topLevelDoc.optionsCommonMark}' $out/reference/flake-parts-options.md
          sed -i '/<!-- OPTIONS:persystem -->/r ${perSystemDoc.optionsCommonMark}' $out/reference/flake-parts-options.md
          sed -i '/<!-- OPTIONS:container -->/r ${containerDoc.optionsCommonMark}' $out/reference/flake-parts-options.md
          sed -i '/<!-- OPTIONS:deploy -->/r ${deployDoc.optionsCommonMark}' $out/reference/nixos-options.md
          sed -i '/<!-- OPTIONS:deploy -->/r ${deployDoc.optionsCommonMark}' $out/reference/home-manager-options.md
          sed -i '/<!-- OPTIONS:nixos-container -->/r ${nixosContainerDoc.optionsCommonMark}' $out/reference/nix-oci-container-module-options.md

          # --- Examples (single group, all categories with prefix) ---
          nix_to_md() {
            local src="$1" dest="$2" title="$3"
            {
              echo "+++"
              echo "title = \"$title\""
              echo "+++"
              echo ""
              echo "# $title"
              echo ""
              echo '```nix'
              cat "$src"
              echo '```'
            } > "$dest"
          }

          for f in $(find ${../examples}/build -name '*.nix' -type f | sort); do
            relpath="''${f#${../examples}/build/}"
            name="''${relpath%.nix}"
            safe_name="build-$(echo "$name" | tr '/' '-')"
            title="[build] $(echo "$name" | tr '/' '-' | tr '-' ' ')"
            nix_to_md "$f" "$out/examples/$safe_name.md" "$title"
          done

          for f in $(find ${../examples}/deploy-nixos -name '*.nix' -type f | sort); do
            name="$(basename "$f" .nix)"
            title="[deploy-nixos] $(echo "$name" | tr '-' ' ')"
            nix_to_md "$f" "$out/examples/deploy-nixos-$name.md" "$title"
          done

          for f in $(find ${../examples}/deploy-home-manager -name '*.nix' -type f | sort); do
            name="$(basename "$f" .nix)"
            title="[deploy-hm] $(echo "$name" | tr '-' ' ')"
            nix_to_md "$f" "$out/examples/deploy-hm-$name.md" "$title"
          done
        '';

        # --- NDG site build (using CLI directly) ---
        ndgConfig = pkgs.writers.writeTOML "ndg.toml" {
          title = "nix-oci";
          input_dir = "${docsInputDir}";
          output_dir = placeholder "out";
          module_options = "${mergedOptionsJSON}";
          search.enable = true;
          highlight_code = true;
          sidebar = {
            options.depth = 3;
            ordering = "custom";
            group_by_dir = true;
            matches = [
              { path = "getting-started.md"; new_title = "Getting Started"; position = 1; }
              { path = "how-to"; position = 1; }
              { path = "reference"; position = 2; }
              { path = "examples"; position = 3; }
            ];
          };
        };

        docs = pkgs.runCommandLocal "nix-oci-docs" {
          nativeBuildInputs = [ ndg ];
        } ''
          ndg --config-file "${ndgConfig}" --verbose html \
            --template-dir ${../docs/templates} \
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
