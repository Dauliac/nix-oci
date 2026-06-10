# Register identity parsing functions in flake-parts nix-lib.
#
# Provides `config.lib.oci.identity.{parsePasswdFile,parseGroupFile,gidToGroupName,packageName}`.
# Pure library: nix/lib/identity.nix
{ ... }:
let
  identityLib = import ../../../lib/identity.nix;
in
{
  config.perSystem =
    { lib, ... }:
    let
      identity = identityLib { inherit lib; };
    in
    {
      nix-lib.lib.oci.identity = {
        packageName = {
          type = lib.types.functionTo lib.types.str;
          description = ''
            Resolve package identity name (pname or parsed derivation name).
            Used for deriving container user names from packages.

            Unlike `resolveMainProgram` (which finds the binary), this returns
            the package identity (e.g. "redis" not "redis-cli").
          '';
          file = "nix/lib/identity.nix";
          fn = identity.packageName;
        };

        parsePasswdFile = {
          type = lib.types.functionTo (lib.types.listOf lib.types.attrs);
          description = ''
            Parse an /etc/passwd file into a list of user records.
            Each record has: name, uid, gid, home, shell.
            Skips empty lines and comments.
          '';
          file = "nix/lib/identity.nix";
          fn = identity.parsePasswdFile;
          tests = {
            "parses standard passwd line" = {
              args = "root:x:0:0:root:/root:/bin/bash";
              expected = [
                {
                  name = "root";
                  uid = "0";
                  gid = "0";
                  home = "/root";
                  shell = "/bin/bash";
                }
              ];
            };
            "parses multiple users" = {
              args = "root:x:0:0:root:/root:/bin/bash\nnobody:x:65534:65534:Nobody:/nonexistent:/usr/sbin/nologin";
              assertions = [
                {
                  name = "has 2 entries";
                  check = r: builtins.length r == 2;
                }
                {
                  name = "second user is nobody";
                  check = r: (builtins.elemAt r 1).name == "nobody";
                }
              ];
            };
            "skips empty lines and comments" = {
              args = "# comment\n\nroot:x:0:0:root:/root:/bin/bash\n";
              assertions = [
                {
                  name = "has 1 entry";
                  check = r: builtins.length r == 1;
                }
              ];
            };
            "skips malformed lines" = {
              args = "incomplete:x:0";
              expected = [ ];
            };
          };
        };

        parseGroupFile = {
          type = lib.types.functionTo (lib.types.listOf lib.types.attrs);
          description = ''
            Parse an /etc/group file into a list of group records.
            Each record has: name, gid.
            Skips empty lines and comments.
          '';
          file = "nix/lib/identity.nix";
          fn = identity.parseGroupFile;
          tests = {
            "parses standard group line" = {
              args = "root:x:0:";
              expected = [
                {
                  name = "root";
                  gid = "0";
                }
              ];
            };
            "parses multiple groups" = {
              args = "root:x:0:\nnogroup:x:65534:";
              assertions = [
                {
                  name = "has 2 entries";
                  check = r: builtins.length r == 2;
                }
              ];
            };
          };
        };

        gidToGroupName = {
          type = lib.types.functionTo lib.types.attrs;
          description = ''
            Build a GID -> group name mapping from parsed group entries.

            Example: `[{ name = "root"; gid = "0"; }]` -> `{ "0" = "root"; }`
          '';
          file = "nix/lib/identity.nix";
          fn = identity.gidToGroupName;
          tests = {
            "maps gid to name" = {
              args = [
                {
                  name = "root";
                  gid = "0";
                }
                {
                  name = "nogroup";
                  gid = "65534";
                }
              ];
              expected = {
                "0" = "root";
                "65534" = "nogroup";
              };
            };
          };
        };
      };
    };
}
