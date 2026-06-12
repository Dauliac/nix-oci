# Hardware capabilities (hwcaps) architecture validation.
{
  lib,
  helpers,
}:
ctx:
let
  inherit (ctx) name containerConfig system;
  perf = containerConfig.performance or { };
  hwcaps = perf.hwcaps or { };
  hwcapsEnabled = hwcaps.enable or false;
  hwcapsLevels = hwcaps.levels or [ ];
  validLevels = if system != null then helpers.hwcapsLevelsForSystem.${system} or [ ] else [ ];
  hwcapsUnsupported = system != null && hwcapsEnabled && validLevels == [ ];
  invalidHwcapsLevels =
    if system != null && hwcapsEnabled && validLevels != [ ] then
      builtins.filter (l: !(lib.elem l validLevels)) hwcapsLevels
    else
      [ ];
in
# Unsupported architecture
(
  if hwcapsUnsupported then
    throw ''
      Container "${name}": `performance.hwcaps.enable = true` but architecture
      "${system}" does not support glibc-hwcaps. Only x86_64-linux supports
      hwcaps levels (x86-64-v2, x86-64-v3, x86-64-v4).
      Fix: remove `performance.hwcaps.enable` or set it to `false` for this arch.
    ''
  else
    ""
)
# Invalid levels for architecture
+ (
  if invalidHwcapsLevels != [ ] then
    throw ''
      Container "${name}": invalid hwcaps levels for ${toString system}: ${
        lib.concatStringsSep ", " (map (l: ''"${l}"'') invalidHwcapsLevels)
      }.
      Valid levels for ${toString system}: ${lib.concatStringsSep ", " validLevels}
    ''
  else
    ""
)
