# Layer strategy coherence check.
{ lib, helpers }:
ctx:
let
  inherit (ctx) name containerConfig;
  layerStrategyIgnored =
    !(containerConfig.optimizeLayers or false)
    && (containerConfig.layerStrategy or "fine-grained") != "fine-grained";
in
if layerStrategyIgnored then
  builtins.trace ''
    WARNING: Container "${name}": `layerStrategy = "${
      containerConfig.layerStrategy or "fine-grained"
    }"` is set
    but `optimizeLayers = false`. The layerStrategy only takes effect when
    `optimizeLayers = true`. Fix: set `optimizeLayers = true` or remove `layerStrategy`.
  '' ""
else
  ""
