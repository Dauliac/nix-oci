# Shared: hardening master switch.
{
  lib,
  ...
}:
{
  options.hardening.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Enable container security hardening.

      When enabled, applies build-time filesystem restrictions and
      generates runtime security hints consumed by deploy modules.

      Three independent kernel primitives are available:
      - **Seccomp** -- syscall filtering (BPF at the syscall boundary)
      - **Landlock** -- object-level access control (LSM hooks at VFS level)
      - **Capabilities + flags** -- privilege restriction at runtime

      For containers using `nixosConfig`, these options are forwarded
      to the inner NixOS module at `oci.container.hardening` and can
      be overridden through NixOS module composition.

      Full container example:
      ```nix
      ${builtins.readFile (../../../../../../examples/option-snippets/hardening/enable.nix)}
      ```
    '';
  };
}
