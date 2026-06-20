# Per-container: computed OCI image built from shared options via nix2container.
#
# Dual-path build:
#   1. When nixosConfig.eval is present: uses the full NixOS eval output
#      (rootFilesystem, entrypoint, healthcheck, envVars, labels, etc.)
#      — same pipeline as flake-parts mkOCIImage.
#   2. When nixosConfig.eval is null (bare package mode): uses ociLib.mkRoot
#      for backward compatibility.
{
  name,
  config,
  lib,
  pkgs,
  nix2container,
  ociLib,
  ...
}:
let
  # Force-evaluate integration checks (throws on errors, traces on warnings).
  _nixosChecks = config.nixosConfig._checks or "";

  nixosEval = config.nixosConfig.eval or null;
  useNixosEval = nixosEval != null;
  out = if useNixosEval then nixosEval.oci.container._output else null;

  # ── Legacy path (no nixosConfig) ──────────────────────────────────────

  # Shadow setup + package + deps as a single buildEnv.
  legacyRoot = ociLib.mkRoot {
    inherit name pkgs;
    inherit (config)
      package
      dependencies
      isRoot
      user
      ;
  };

  # Separate shadow setup (without deps/package) for optimized layering.
  legacyShadowOnly = ociLib.mkShadowSetup {
    inherit (config) isRoot user;
    inherit pkgs;
    runtimeShell = pkgs.runtimeShell;
  };

  legacyEntrypoint =
    if config.entrypoint != [ ] then
      config.entrypoint
    else if config.package != null then
      let
        mainProgram = config.package.meta.mainProgram or config.package.pname or name;
      in
      [ "${config.package}/bin/${mainProgram}" ]
    else
      [ ];

  legacyHardenedConfigs = ociLib.mkHardenedConfigs {
    inherit (config) hardening;
    inherit pkgs;
  };

  # ── Shared helpers ────────────────────────────────────────────────────

  # Auto-generated labels (OCI standard + build info + hardening + PSS).
  generatedLabels = ociLib.mkAutoLabels {
    inherit (config)
      name
      tag
      package
      isRoot
      optimizeLayers
      hardening
      ports
      dependencies
      ;
    layerStrategy = config.layerStrategy or "fine-grained";
    system = pkgs.stdenv.hostPlatform.system;
    autoLabels = config.autoLabels or true;
  };

  # ── OCI config (dual-path) ───────────────────────────────────────────

  ociConfig =
    if useNixosEval then
      # Rich path: same as mkOCIImage
      {
        entrypoint = if out.entrypoint != [ ] then out.entrypoint else config.entrypoint;
        User = if config.isRoot then "root" else config.user;
        Env = out.envVars;
        Labels =
          generatedLabels
          // (nixosEval.oci.container.generatedLabels or { })
          // (config.labels or { });
      }
      // lib.optionalAttrs (config.ports != [ ]) {
        ExposedPorts = ociLib.mkExposedPorts config.ports;
      }
      // (
        let
          hc = out.healthcheck or null;
        in
        lib.optionalAttrs (hc != null) {
          Healthcheck = {
            Test = [ "CMD" ] ++ hc.command;
            Interval = hc.interval * 1000000000;
            Timeout = hc.timeout * 1000000000;
            StartPeriod = hc.startPeriod * 1000000000;
            Retries = hc.retries;
          };
        }
      )
      // lib.optionalAttrs ((out.stopSignal or null) != null) {
        StopSignal = out.stopSignal;
      }
      // lib.optionalAttrs ((out.workingDir or null) != null) {
        WorkingDir = out.workingDir;
      }
      // (
        let
          vols = out.declaredVolumes or [ ];
        in
        lib.optionalAttrs (vols != [ ]) {
          Volumes = builtins.listToAttrs (map (v: lib.nameValuePair v { }) vols);
        }
      )
    else
      # Legacy path: existing behavior
      {
        entrypoint = legacyEntrypoint;
        User = if config.isRoot then "root" else config.user;
      }
      // lib.optionalAttrs (config.ports != [ ]) {
        ExposedPorts = ociLib.mkExposedPorts config.ports;
      }
      // lib.optionalAttrs (config.environment != { }) {
        Env = lib.mapAttrsToList (k: v: "${k}=${v}") config.environment;
      }
      // {
        Labels = generatedLabels // (config.labels or { });
      }
      // lib.optionalAttrs (config.healthcheck.command != [ ]) {
        Healthcheck = {
          Test = [ "CMD" ] ++ config.healthcheck.command;
          Interval = config.healthcheck.interval * 1000000000;
          Timeout = config.healthcheck.timeout * 1000000000;
          StartPeriod = config.healthcheck.startPeriod * 1000000000;
          Retries = config.healthcheck.retries;
        };
      }
      // lib.optionalAttrs (config.stopSignal != null) {
        StopSignal = config.stopSignal;
      }
      // lib.optionalAttrs (config.workingDir != null) {
        WorkingDir = config.workingDir;
      }
      // lib.optionalAttrs (config.declaredVolumes != [ ]) {
        Volumes = builtins.listToAttrs (map (v: lib.nameValuePair v { }) config.declaredVolumes);
      };

  # ── Root filesystem / layers (dual-path) ─────────────────────────────

  optimized = config.optimizeLayers;
  layerStrategy = config.layerStrategy or "fine-grained";

  # Rich path: rootFilesystem from NixOS eval (includes shadow, etc, deps, home).
  evalCopyToRoot = [ out.rootFilesystem ];

  # Legacy path: optimized layers from raw options.
  legacyRootPaths =
    legacyShadowOnly ++ legacyHardenedConfigs ++ lib.optional (config.package != null) config.package;

  copyToRoot = if useNixosEval then evalCopyToRoot else [ legacyRoot ];

  # hwcaps layers from container-level performance.hwcaps sugar
  # (same logic as mkOCIImage on the flake-parts side).
  hwcapsCfg = config.performance.hwcaps or { enable = false; };
  hwcapsLayers = lib.optionals (hwcapsCfg.enable or false) (
    map (
      level:
      ociLib.mkHwcapsLayer {
        inherit pkgs nix2container level;
        libraries = hwcapsCfg.libraries or [ ];
      }
    ) (hwcapsCfg.levels or [ ])
  );

  layers =
    (ociLib.mkImageLayers {
      inherit pkgs nix2container layerStrategy;
      inherit (config) dependencies;
      rootPaths = if useNixosEval then evalCopyToRoot else legacyRootPaths;
    })
    ++ hwcapsLayers;
in
{
  options.image = lib.mkOption {
    type = lib.types.package;
    readOnly = true;
    description = "Built OCI image (computed from package + dependencies via nix2container).";
    default =
      assert _nixosChecks == "" || _nixosChecks != "";
      nix2container.buildImage (
        {
          name = config.name;
          tag = config.tag;
          config = ociConfig;
        }
        // (
          if optimized then
            {
              inherit layers;
            }
            // lib.optionalAttrs (layerStrategy == "fine-grained") {
              maxLayers = 40;
            }
          else
            {
              inherit copyToRoot;
            }
            // lib.optionalAttrs (hwcapsLayers != [ ]) {
              layers = hwcapsLayers;
            }
        )
      );
  };
}
