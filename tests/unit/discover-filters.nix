# Unit tests for discoverModules + discoverFilters.
#
# Evaluate with:
#   nix eval --file tests/unit/discover-filters.nix
#
# Returns true when all assertions pass; throws on failure.
let
  # Both functions require { lib } as first argument.
  nixpkgs = builtins.getFlake "nixpkgs";
  lib = nixpkgs.lib;
  discoverModules = import ../../nix/lib/discoverModules.nix { inherit lib; };
  filters = import ../../nix/lib/discoverFilters.nix { inherit lib; };

  fixtureDir = ./fixtures/discover-filters;
  optionsDir = ../../nix/modules/oci/containers/_options;

  # Helper: extract basenames from a list of paths for easier comparison.
  basenames = builtins.map (p: builtins.baseNameOf (toString p));

  # Helper: check whether a name is in a list.
  elem = x: xs: builtins.elem x xs;

  # ── Fixture-based tests ──────────────────────────────────────────────

  # 1. filters.options: should return foo.nix + bar/baz.nix only
  #    (excludes foo.lib.nix, foo.test.nix, default.nix)
  optionsResult = discoverModules {
    dir = fixtureDir;
    filter = filters.options;
  };
  optionsNames = basenames optionsResult;

  # 2. filters.lib: should return foo.lib.nix + bar/baz.lib.nix only
  libResult = discoverModules {
    dir = fixtureDir;
    filter = filters.lib;
  };
  libNames = basenames libResult;

  # 3. filters.test: should return foo.test.nix only
  testResult = discoverModules {
    dir = fixtureDir;
    filter = filters.test;
  };
  testNames = basenames testResult;

  # 4. Backward compatibility: bare path should return all .nix files
  bareResult = discoverModules fixtureDir;
  bareNames = basenames bareResult;

  # 5. Backward compat with { dir } only (no filter) should also return all .nix
  dirOnlyResult = discoverModules { dir = fixtureDir; };
  dirOnlyNames = basenames dirOnlyResult;

  # ── Real-directory tests ─────────────────────────────────────────────

  # 6. Using filters.options on the real _options/ directory:
  #    no .lib.nix or .test.nix files should appear.
  realOptionsResult = discoverModules {
    dir = optionsDir;
    filter = filters.options;
  };
  realOptionsNames = basenames realOptionsResult;
  hasLibFile = builtins.any (n: builtins.match ".*\\.lib\\.nix" n != null) realOptionsNames;
  hasTestFile = builtins.any (n: builtins.match ".*\\.test\\.nix" n != null) realOptionsNames;

  # 7. Unfiltered count on _options/ should match options-filtered count
  #    (since _options/ contains no .lib.nix, .test.nix, or default.nix files).
  realAllResult = discoverModules optionsDir;
  realAllNames = basenames realAllResult;

  # ── Assertions ───────────────────────────────────────────────────────

  assertions = [
    {
      name = "filters.options returns foo.nix";
      cond = elem "foo.nix" optionsNames;
    }
    {
      name = "filters.options returns baz.nix from subdir";
      cond = elem "baz.nix" optionsNames;
    }
    {
      name = "filters.options excludes foo.lib.nix";
      cond = !(elem "foo.lib.nix" optionsNames);
    }
    {
      name = "filters.options excludes foo.test.nix";
      cond = !(elem "foo.test.nix" optionsNames);
    }
    {
      name = "filters.options excludes default.nix";
      cond = !(elem "default.nix" optionsNames);
    }
    {
      name = "filters.options returns exactly 2 files";
      cond = builtins.length optionsResult == 2;
    }
    {
      name = "filters.lib returns foo.lib.nix";
      cond = elem "foo.lib.nix" libNames;
    }
    {
      name = "filters.lib returns baz.lib.nix from subdir";
      cond = elem "baz.lib.nix" libNames;
    }
    {
      name = "filters.lib returns exactly 2 files";
      cond = builtins.length libResult == 2;
    }
    {
      name = "filters.test returns foo.test.nix";
      cond = elem "foo.test.nix" testNames;
    }
    {
      name = "filters.test returns exactly 1 file";
      cond = builtins.length testResult == 1;
    }
    {
      name = "bare path returns all 6 .nix files";
      cond = builtins.length bareResult == 6;
    }
    {
      name = "bare path includes default.nix";
      cond = elem "default.nix" bareNames;
    }
    {
      name = "bare path includes foo.lib.nix";
      cond = elem "foo.lib.nix" bareNames;
    }
    {
      name = "bare path includes foo.test.nix";
      cond = elem "foo.test.nix" bareNames;
    }
    {
      name = "dir-only (no filter) matches bare path count";
      cond = builtins.length dirOnlyResult == builtins.length bareResult;
    }
    {
      name = "real _options/ with filters.options has no .lib.nix files";
      cond = !hasLibFile;
    }
    {
      name = "real _options/ with filters.options has no .test.nix files";
      cond = !hasTestFile;
    }
    {
      name = "real _options/ unfiltered count > 0";
      cond = builtins.length realAllResult > 0;
    }
  ];

  failed = builtins.filter (a: !a.cond) assertions;
  failedNames = builtins.map (a: a.name) failed;
in
if failed == [ ] then
  true
else
  builtins.throw "discover-filters: ${toString (builtins.length failed)} assertion(s) failed: ${builtins.concatStringsSep "; " failedNames}"
