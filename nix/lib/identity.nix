# Pure identity parsing functions for OCI base image integration.
#
# Parses /etc/passwd and /etc/group files into structured data.
# Used by eval-container.nix for fromImage base image support.
# Wrapped by nix-lib (nix/modules/oci/lib/identity.nix).
{ lib }:
let
  inherit (lib) strings;
in
{
  # Resolve package identity for user name: pname -> parsed drv name.
  # Unlike image naming (which uses mainProgram), user names should
  # reflect the package identity (e.g. "redis" not "redis-cli").
  packageName =
    pkg:
    if pkg.pname or null != null then
      pkg.pname
    else
      (builtins.parseDrvName (pkg.name or "unknown")).name;

  # Parse a passwd file into a list of { name, uid, gid, home, shell }.
  # Format: name:x:uid:gid:gecos:home:shell
  parsePasswdFile =
    content:
    let
      lines = builtins.filter (l: l != "" && !(strings.hasPrefix "#" l)) (
        strings.splitString "\n" content
      );
      parseLine =
        line:
        let
          parts = strings.splitString ":" line;
          len = builtins.length parts;
        in
        if len >= 7 then
          {
            name = builtins.elemAt parts 0;
            uid = builtins.elemAt parts 2;
            gid = builtins.elemAt parts 3;
            home = builtins.elemAt parts 5;
            shell = builtins.elemAt parts 6;
          }
        else
          null;
      parsed = map parseLine lines;
    in
    builtins.filter (x: x != null) parsed;

  # Parse a group file into a list of { name, gid }.
  # Format: name:x:gid:members
  parseGroupFile =
    content:
    let
      lines = builtins.filter (l: l != "" && !(strings.hasPrefix "#" l)) (
        strings.splitString "\n" content
      );
      parseLine =
        line:
        let
          parts = strings.splitString ":" line;
          len = builtins.length parts;
        in
        if len >= 3 then
          {
            name = builtins.elemAt parts 0;
            gid = builtins.elemAt parts 2;
          }
        else
          null;
      parsed = map parseLine lines;
    in
    builtins.filter (x: x != null) parsed;

  # Build a GID -> group name mapping from parsed group entries.
  gidToGroupName = groups: builtins.listToAttrs (map (g: lib.nameValuePair g.gid g.name) groups);
}
