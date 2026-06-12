# Pure Nix function that generates Python pytest code from BDD test spec assertions.
#
# Prefixed with _ so import-tree does not auto-import this as a module.
#
# Usage:
#   let gen = import ./_python-gen.nix { inherit lib; };
#   in gen.mkPytestFunction { containerName = "my-app"; assertions = spec.assertions; }
{ lib }:
let
  inherit (lib)
    concatStringsSep
    concatMapStringsSep
    optionalString
    mapAttrsToList
    ;

  # Escape a string for embedding in Python source (double-quoted).
  pyStr = s: ''"${lib.replaceStrings [ ''"'' "\\" "\n" ] [ ''\"'' "\\\\" "\\n" ] s}"'';

  # Indent every line by n spaces.
  indent =
    n: s:
    let
      pad = concatStringsSep "" (builtins.genList (_: " ") n);
    in
    concatMapStringsSep "\n" (line: if line == "" then "" else "${pad}${line}") (
      lib.splitString "\n" s
    );

  # Generate a docstring from BDD given/when/then.
  mkDocstring =
    given: bddWhen: bddThen:
    let
      parts =
        (optionalString (given != "") "Given: ${given}\n")
        + (optionalString (bddWhen != "") "When: ${bddWhen}\n")
        + (optionalString (bddThen != "") "Then: ${bddThen}\n");
    in
    optionalString (parts != "") ''
      """
      ${lib.removeSuffix "\n" parts}
      """
    '';

  # Generate code for a single "succeeds" assertion.
  mkSucceeds =
    containerName: entry:
    let
      argsLine = if entry.args != "" then "command=${pyStr entry.args}," else "command=None,";
      stdoutCheck = optionalString (entry.stdout != null) ''
        stdout = result.decode("utf-8", errors="replace") if isinstance(result, bytes) else str(result)
        assert ${pyStr entry.stdout} in stdout, (
            f"Expected stdout to contain ${pyStr entry.stdout}, got: {stdout[:500]}"
        )
      '';
    in
    ''
      # succeeds: ${entry.command} ${entry.args}
      result = client.containers.run(
          ${pyStr "${containerName}:latest"},
          entrypoint=${pyStr entry.command},
          ${argsLine}
          remove=True,
      )
      ${stdoutCheck}
    '';

  # Generate code for a single "fails" assertion.
  mkFails =
    containerName: entry:
    let
      exitCodeCheck =
        if entry.exitCode != null then
          ''
            assert e.exit_status == ${toString entry.exitCode}, (
                f"Expected exit code ${toString entry.exitCode}, got {e.exit_status}"
            )
          ''
        else
          "";
    in
    ''
      # fails: ${entry.command} ${entry.args}
      try:
          client.containers.run(
              ${pyStr "${containerName}:latest"},
              entrypoint=${pyStr entry.command},
              ${if entry.args != "" then "command=${pyStr entry.args}," else "command=None,"}
              remove=True,
          )
          pytest.fail("Expected non-zero exit from ${entry.command}")
      except docker.errors.ContainerError as e:
          ${
            if exitCodeCheck != "" then
              lib.removeSuffix "\n" exitCodeCheck
            else
              "pass  # any non-zero exit is acceptable"
          }
    '';

  # Generate code for httpResponds assertion.
  mkHttpResponds =
    containerName: http:
    let
      containsCheck = optionalString (http.contains != "") ''
        assert ${pyStr http.contains} in resp.text, (
            f"Expected response to contain ${pyStr http.contains}, got: {resp.text[:500]}"
        )
      '';
    in
    ''
      # httpResponds: port ${toString http.port} path ${http.path}
      import requests
      import time
      url = f"http://localhost:${toString http.port}${http.path}"
      deadline = time.time() + 30
      last_err = None
      while time.time() < deadline:
          try:
              resp = requests.get(url, timeout=5)
              resp.raise_for_status()
              break
          except Exception as exc:
              last_err = exc
              time.sleep(1)
      else:
          raise TimeoutError(f"{url} did not respond within 30s: {last_err}")
      ${containsCheck}
    '';

  # Generate code for processEnv assertions.
  mkProcessEnv =
    containerName: envAttrs:
    let
      checks = mapAttrsToList (key: value: ''
        assert ${pyStr key} in env_dict, (
            f"Expected env var ${pyStr key}, got keys: {list(env_dict)}"
        )
        assert ${pyStr value} in env_dict[${pyStr key}], (
            f"Expected ${pyStr key} to contain ${pyStr value}, got: {env_dict[${pyStr key}]!r}"
        )
      '') envAttrs;
    in
    ''
      # processEnv checks
      proc_output = client.containers.run(
          ${pyStr "${containerName}:latest"},
          entrypoint="/bin/cat",
          command="/proc/1/environ",
          remove=True,
      )
      raw = proc_output.decode("utf-8", errors="replace") if isinstance(proc_output, bytes) else str(proc_output)
      env_pairs = raw.split("\x00")
      env_dict = {}
      for pair in env_pairs:
          if "=" in pair:
              k, _, v = pair.partition("=")
              env_dict[k] = v
      ${concatStringsSep "\n" checks}
    '';

  # Generate code for imageConfig assertions.
  mkImageConfig =
    containerName: configAttrs:
    let
      checks = mapAttrsToList (key: value: ''
        assert config.get(${pyStr key}) == ${pyStr (builtins.toJSON value)}, (
            f"Expected Config.${key} == ${builtins.toJSON value}, got: {config.get(${pyStr key})!r}"
        )
      '') configAttrs;
    in
    ''
      # imageConfig checks
      inspect = client.api.inspect_image(${pyStr "${containerName}:latest"})
      config = inspect.get("Config", {})
      ${concatStringsSep "\n" checks}
    '';

  # Generate code for labels assertions.
  mkLabels =
    containerName: labelAttrs:
    let
      checks = mapAttrsToList (key: value: ''
        assert labels.get(${pyStr key}) == ${pyStr value}, (
            f"Expected label ${key}=${pyStr value}, got: {labels.get(${pyStr key})!r}"
        )
      '') labelAttrs;
    in
    ''
      # labels checks
      inspect = client.api.inspect_image(${pyStr "${containerName}:latest"})
      labels = inspect.get("Config", {}).get("Labels", {})
      ${concatStringsSep "\n" checks}
    '';

  # Generate code for fileContains assertions.
  mkFileContains =
    containerName: fileAttrs:
    let
      checks = mapAttrsToList (path: expected: ''
        ih.assert_file_contains(${pyStr path}, ${pyStr expected})
      '') fileAttrs;
    in
    ''
      # fileContains checks
      ih = ImageHelper(client, ${pyStr "${containerName}:latest"})
      ${concatStringsSep "" checks}
    '';

  # Generate code for fileNotContains assertions.
  mkFileNotContains =
    containerName: fileAttrs:
    let
      checks = mapAttrsToList (path: excluded: ''
        ih.assert_file_not_contains(${pyStr path}, ${pyStr excluded})
      '') fileAttrs;
    in
    ''
      # fileNotContains checks
      ih = ImageHelper(client, ${pyStr "${containerName}:latest"})
      ${concatStringsSep "" checks}
    '';
in
{
  # Generate a pytest function body from BDD assertions.
  #
  # containerName: string (podman container name, without :latest tag)
  # assertions: the assertions attrset from the test spec
  # given, when, then: BDD metadata strings (optional)
  #
  # Returns: string of Python code (one test function body)
  mkPytestFunction =
    args:
    let
      containerName = args.containerName;
      assertions = args.assertions;
      given = args.given or "";
      bddWhen = args.${"when"} or "";
      bddThen = args.${"then"} or "";

      a = assertions;

      docstring = mkDocstring given bddWhen bddThen;

      sections =
        (optionalString (a.imageConfig or { } != { }) (mkImageConfig containerName a.imageConfig))
        + (optionalString (a.labels or { } != { }) (mkLabels containerName a.labels))
        + (optionalString (a.fileContains or { } != { }) (mkFileContains containerName a.fileContains))
        + (optionalString (a.fileNotContains or { } != { }) (
          mkFileNotContains containerName a.fileNotContains
        ))
        + (concatMapStringsSep "\n" (mkSucceeds containerName) (a.succeeds or [ ]))
        + (concatMapStringsSep "\n" (mkFails containerName) (a.fails or [ ]))
        + (optionalString (a.httpResponds or null != null) (mkHttpResponds containerName a.httpResponds))
        + (optionalString (a.processEnv or { } != { }) (mkProcessEnv containerName a.processEnv))
        + (optionalString (a.runtime or "" != "") ''
          # runtime (escape hatch)
          ${a.runtime}
        '');
    in
    ''
      def test_${lib.replaceStrings [ "-" "." ] [ "_" "_" ] containerName}(client):
          ${if docstring != "" then docstring else ""}${indent 4 sections}
    '';
}
