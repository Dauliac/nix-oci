# Flavour expansion - evaluate synthetic containers from flavour definitions
#
# For each container with non-empty `flavours`, this module evaluates a
# synthetic container via lib.evalModules using:
#   1. The full collected perContainer module pipeline (eval, integration, etc.)
#   2. A parent-inheritance module (scalars as mkDefault, lists at normal priority)
#   3. The user's flavour deferredModule
#
# The NixOS module system's merge semantics give us the right behavior:
#   - Lists (dependencies, modules, ports): concatenated (parent ++ flavour)
#   - Attrsets (environment, labels): merged (parent // flavour)
#   - Scalars (package, tag, isRoot): parent mkDefault, flavour overrides
#
# Results are stored in oci.internal._flavourContainers and consumed by
# the build pipeline in internal/packages.nix.
{
  config,
  lib,
  flake-parts-lib,
  ...
}:
let
  cfg = config;
in
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    {
      config,
      system,
      pkgs,
      ...
    }:
    let
      perContainerType = config.oci.perContainer;
      collectedModules = perContainerType._collectedModules;

      # Parent inheritance module - sets parent values as defaults for the
      # synthetic container. The NixOS module system handles the rest:
      #   - mkDefault scalars are overridden by flavour's normal-priority values
      #   - Normal-priority lists are concatenated with flavour's lists
      #   - Normal-priority attrsets are merged with flavour's attrsets
      mkParentInheritance =
        parentConfig: flavourName:
        { lib, ... }:
        {
          # --- Scalars: mkDefault so flavour can override ---
          package = lib.mkDefault parentConfig.package;
          name = lib.mkDefault parentConfig.name;
          tag = lib.mkDefault "${parentConfig.tag}-${flavourName}";
          isRoot = lib.mkDefault parentConfig.isRoot;
          registry = lib.mkDefault (parentConfig.registry or null);
          installNix = lib.mkDefault (parentConfig.installNix or false);
          initializeNixDatabase = lib.mkDefault (parentConfig.initializeNixDatabase or false);
          optimizeLayers = lib.mkDefault (parentConfig.optimizeLayers or false);
          layerStrategy = lib.mkDefault (parentConfig.layerStrategy or "fine-grained");
          autoLabels = lib.mkDefault (parentConfig.autoLabels or true);

          nixosConfig.mainService = lib.mkDefault (parentConfig.nixosConfig.mainService or null);
          homeConfig.homeManagerFlake = lib.mkDefault (parentConfig.homeConfig.homeManagerFlake or null);

          # Structured scalars: mkDefault the whole block
          hardening = lib.mkDefault parentConfig.hardening;
          performance = lib.mkDefault parentConfig.performance;
          healthcheck = lib.mkDefault (parentConfig.healthcheck or { });

          # --- Lists: normal priority for concatenation with flavour ---
          nixosConfig.modules = parentConfig.nixosConfig.modules or [ ];
          homeConfig.modules = parentConfig.homeConfig.modules or [ ];
          dependencies = parentConfig.dependencies or [ ];
          ports = parentConfig.ports or [ ];
          entrypoint = parentConfig.entrypoint or [ ];
          declaredVolumes = parentConfig.declaredVolumes or [ ];

          # --- Attrsets: normal priority for merge with flavour ---
          environment = parentConfig.environment or { };
          labels = parentConfig.labels or { };
          configFiles = parentConfig.configFiles or { };
        };

      expandFlavour =
        containerId: parentConfig: flavourName: flavourModules:
        let
          syntheticId = "${containerId}-${flavourName}";
          evaluated = lib.evalModules {
            modules =
              collectedModules
              ++ [
                # Set internal container name for the synthetic container
                { _containerName = syntheticId; }
                # Parent inheritance
                (mkParentInheritance parentConfig flavourName)
              ]
              ++ flavourModules;
            specialArgs = {
              inherit system pkgs;
              globalConfig = cfg;
              perSystemConfig = config;
            };
            class = "perContainer";
          };
        in
        evaluated.config;

      expandedFlavours = lib.pipe config.oci.containers [
        (lib.concatMapAttrs (
          containerId: container:
          lib.mapAttrs' (
            flavourName: flavourModules:
            lib.nameValuePair "${containerId}-${flavourName}" (
              expandFlavour containerId container flavourName flavourModules
            )
          ) container.flavours
        ))
      ];
    in
    {
      options.oci.internal._flavourContainers = lib.mkOption {
        type = lib.types.attrsOf lib.types.unspecified;
        internal = true;
        readOnly = true;
        description = "Evaluated synthetic containers from flavour expansion.";
        default = expandedFlavours;
      };
    }
  );
}
