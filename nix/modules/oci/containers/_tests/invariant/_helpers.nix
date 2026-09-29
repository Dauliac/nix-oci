# Coherence-assertion regression helper.
#
# Imported by every coherence-*.test.nix file in this directory. Not
# picked up by test-collector.nix (test filter matches only `.test.nix`).
#
# Provides `mkCoherenceCheck`: a pure function that evaluates the
# coherence module against a synthesised hardening / services config,
# wraps the result in `builtins.tryEval` (per design D2), and returns a
# marker attrset the calling test file can inspect at file-load time.
#
# When a coherence assertion is expected to fire, the helper reports
# whether the assertion actually fired and whether its message carries
# the expected tag (P2, S1, ...). The test file then `throw`s if the
# regression is detected, which surfaces at `nix eval .#tests --json`.
{ lib }:
let
  coherenceModule = ../../../../../modules/_nixos-oci/hardening/coherence.nix;

  # Minimal option shape mirroring the slice of nixos-oci that
  # `coherence.nix` reads. Keeping this local avoids pulling the full
  # `_nixos-oci` module tree into the eval and keeps the check
  # standalone.
  mockOptionsModule =
    { lib, ... }:
    {
      options.oci.container.hardening = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        noNewPrivileges = lib.mkOption {
          type = lib.types.bool;
          default = true;
        };
        readOnlyRootfs = lib.mkOption {
          type = lib.types.bool;
          default = true;
        };
        disableDns = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        noTlsTrustStore = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        seccomp = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          profile = lib.mkOption {
            type = lib.types.str;
            default = "moderate";
          };
          customProfileJson = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
          mode = lib.mkOption {
            type = lib.types.str;
            default = "enforce";
          };
        };
        capabilities = {
          add = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };
          drop = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };
        };
        apparmor = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          customProfile = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
          denyMount = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          denyUserNamespace = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          denyPtrace = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          mode = lib.mkOption {
            type = lib.types.str;
            default = "enforce";
          };
        };
      };
      options.assertions = lib.mkOption {
        type = lib.types.listOf lib.types.unspecified;
        default = [ ];
      };
      options.warnings = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
      options.services = lib.mkOption {
        type = lib.types.attrs;
        default = { };
      };
    };

  evalCoherence =
    {
      hardening ? { },
      services ? { },
    }:
    (lib.evalModules {
      modules = [
        mockOptionsModule
        coherenceModule
        {
          oci.container.hardening = hardening;
          inherit services;
        }
      ];
    }).config;

  # Returns { fired, matched, messages, warnings }.
  #   fired    : true if any assertion in the evaluated config failed
  #   matched  : true if a failed assertion's message contains `tag`
  #   messages : concatenated failed-assertion messages (for diagnostics)
  #   warnings : list of warning strings (for D2..G3 checks)
  probe =
    {
      hardening,
      services ? { },
      tag,
    }:
    let
      cfg = evalCoherence { inherit hardening services; };
      wrapped = builtins.tryEval (builtins.deepSeq cfg.assertions cfg.assertions);
      # deepSeq forces list; a throw inside is still caught by tryEval.
      assertions = if wrapped.success then wrapped.value else [ ];
      failed = builtins.filter (a: !a.assertion) assertions;
      messages = lib.concatMapStringsSep "\n---\n" (a: a.message) failed;
      matched = builtins.match ".*${tag}.*" messages != null;
      # The tag string is intentionally free-form ("NET_RAW", "strict",
      # "NET_BIND_SERVICE", ...). We fall back to matching the
      # `nix-oci coherence:` prefix if callers want a "any fired" probe.
      matchedOrAny = if tag == "*" then failed != [ ] else matched;
      warningsWrapped = builtins.tryEval (builtins.deepSeq cfg.warnings cfg.warnings);
      warnings = if warningsWrapped.success then warningsWrapped.value else [ ];
    in
    {
      inherit
        assertions
        failed
        messages
        warnings
        ;
      fired = failed != [ ];
      matched = matchedOrAny;
      warningMatches = wtag: builtins.any (w: builtins.match ".*${wtag}.*" w != null) warnings;
    };

  # Guard used by coherence-*.test.nix files.
  # Throws (breaks `nix eval .#tests --json`) when the expected
  # assertion did NOT fire or its message lost the tag.
  mkCoherenceCheck =
    {
      tag,
      hardening,
      services ? { },
    }:
    let
      p = probe { inherit hardening services tag; };
    in
    if !p.fired then
      throw "nix-oci coherence regression: no assertion fired for tag ${tag}. Fixture: ${builtins.toJSON hardening}"
    else if !p.matched then
      throw "nix-oci coherence regression: assertion fired but message did not match tag ${tag}. Got: ${p.messages}"
    else
      true;

  # Negative guard: ensures a satisfying config produces NO failed
  # assertions. Used by coherence-nofalse.test.nix.
  mkNoAssertionsCheck =
    {
      hardening,
      services ? { },
    }:
    let
      p = probe {
        inherit hardening services;
        tag = "*";
      };
    in
    if p.fired then
      throw "nix-oci coherence regression: satisfying config unexpectedly fired assertions: ${p.messages}"
    else
      true;

  # Warning guard: for D2/D3/D4/D5/D6/G3, verifies a warning is
  # emitted. Warnings are string traces, not eval failures.
  mkWarningCheck =
    {
      warningTag,
      hardening,
      services ? { },
    }:
    let
      p = probe {
        inherit hardening services;
        tag = "*";
      };
    in
    if !(p.warningMatches warningTag) then
      throw "nix-oci coherence regression: no warning matched pattern ${warningTag}. Warnings: ${builtins.toJSON p.warnings}"
    else
      true;
in
{
  inherit
    probe
    mkCoherenceCheck
    mkNoAssertionsCheck
    mkWarningCheck
    ;
}
