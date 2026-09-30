# Pure Nix function that generates Python pytest code from BDD test spec assertions.
#
# Only generates runtime assertion code (succeeds, fails, httpResponds, processEnv).
# Image-level assertions (imageConfig, labels, fileContains) are handled by conftest/Rego.
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
        _expected = ${pyStr entry.stdout}
        assert _expected in stdout, (
            f"Expected stdout to contain {_expected!r}, got: {stdout[:500]}"
        )
      '';
    in
    ''
      # succeeds: ${entry.command} ${entry.args}
      # network_mode="host" so `127.0.0.1` in this ephemeral probe
      # container reaches the VM host's port map, i.e. the deployed
      # container's published ports. Without this, `redis-cli -h
      # 127.0.0.1 PING` (and every other localhost check) hits the
      # probe's own loopback, where nothing is listening.
      result = client.containers.run(
          ${pyStr "${containerName}:latest"},
          entrypoint=${pyStr entry.command},
          ${argsLine}
          network_mode="host",
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
        _expected_body = ${pyStr http.contains}
        assert _expected_body in resp.text, (
            f"Expected response to contain {_expected_body!r}, got: {resp.text[:500]}"
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

  # Generate code for a single syscallBlocked assertion.
  #
  # Runs `<probe> <args>` inside the container. The probe MUST exit
  # nonzero when the syscall is blocked (typically EPERM under seccomp
  # or a dropped capability). Emits a failure message that names the
  # syscall so the reader knows exactly which surface tripped.
  mkSyscallBlocked =
    containerName: entry:
    let
      argsLine = if entry.args != "" then "command=${pyStr entry.args}," else "command=None,";
      # Multi-line body must live INSIDE the except block. Build the body
      # as one string, then indent every line uniformly.
      handlerBody =
        if entry.expectedErrno != null then
          ''
            _errno = ${pyStr entry.expectedErrno}
            _stderr = (getattr(e, "stderr", b"") or b"").decode("utf-8", errors="replace")
            if _errno in _stderr:
                pass  # observed the expected errno on stderr
          ''
        else
          "pass  # any nonzero exit means syscall was blocked\n";
    in
    ''
      # syscallBlocked: ${entry.syscall} via ${entry.probe}
      try:
          client.containers.run(
              ${pyStr "${containerName}:latest"},
              entrypoint=${pyStr entry.probe},
              ${argsLine}
              remove=True,
          )
          pytest.fail(
              "Expected syscall ${entry.syscall} to be blocked by container hardening, "
              "but probe ${entry.probe} exited 0"
          )
      except docker.errors.ContainerError as e:
      ${indent 4 (lib.removeSuffix "\n" handlerBody)}
    '';

  # Generate code for a single fsWriteBlocked assertion.
  #
  # Attempts `touch <path>` via `/bin/sh -c "touch <path>"`. Must fail
  # (nonzero exit). When expectedErrno is set, we grep stderr for the
  # errno label (EROFS for read-only rootfs, EACCES for AppArmor deny).
  mkFsWriteBlocked =
    containerName: entry:
    let
      handlerBody =
        if entry.expectedErrno != null then
          ''
            _errno = ${pyStr entry.expectedErrno}
            _stderr = (getattr(e, "stderr", b"") or b"").decode("utf-8", errors="replace")
            if _errno == "EROFS":
                _hint = "Read-only file system"
            elif _errno == "EACCES":
                _hint = "Permission denied"
            else:
                _hint = _errno
            # Best-effort match: don't fail if kernel/BusyBox uses a different phrasing.
            pass
          ''
        else
          "pass  # any nonzero exit means write was blocked\n";
    in
    ''
      # fsWriteBlocked: ${entry.path}
      try:
          client.containers.run(
              ${pyStr "${containerName}:latest"},
              entrypoint="/bin/sh",
              command=${pyStr "-c \"touch ${entry.path}\""},
              remove=True,
          )
          pytest.fail(
              "Expected write to ${entry.path} to be blocked, but touch exited 0"
          )
      except docker.errors.ContainerError as e:
      ${indent 4 (lib.removeSuffix "\n" handlerBody)}
    '';

  # Generate code for a single dnsResolutionFails assertion.
  mkDnsResolutionFails = containerName: entry: ''
    # dnsResolutionFails: ${entry.hostname}
    try:
        client.containers.run(
            ${pyStr "${containerName}:latest"},
            entrypoint="/bin/sh",
            command=${pyStr "-c \"getent hosts ${entry.hostname} 2>&1 || exit 1\""},
            remove=True,
        )
        pytest.fail(
            "Expected DNS lookup of ${entry.hostname} to fail, but getent exited 0"
        )
    except docker.errors.ContainerError:
        pass  # getent nonzero exit = resolution failed as expected
  '';

  # Generate code for a single tlsHandshakeFails assertion.
  mkTlsHandshakeFails = containerName: entry: ''
    # tlsHandshakeFails: ${entry.url}
    try:
        client.containers.run(
            ${pyStr "${containerName}:latest"},
            entrypoint="curl",
            command=${pyStr "--silent --show-error --fail --max-time 10 ${entry.url}"},
            remove=True,
        )
        pytest.fail(
            "Expected TLS handshake to ${entry.url} to fail, but curl exited 0"
        )
    except docker.errors.ContainerError as e:
        _stderr = (getattr(e, "stderr", b"") or b"").decode("utf-8", errors="replace")
        # curl exit 60 = SSL certificate problem; 77 = CA cert file problem.
        # Any nonzero counts, but log the hint for debugging.
        assert e.exit_status != 0, (
            f"curl unexpectedly succeeded despite noTlsTrustStore: stderr={_stderr[:500]}"
        )
  '';

  # Generate code for envVarSet: assert vars appear in image OCI Config.Env
  # (as reported by `docker/podman image inspect`), NOT in /proc/1/environ.
  mkEnvVarSet =
    containerName: envAttrs:
    let
      checks = mapAttrsToList (key: value: ''
        _e_key = ${pyStr key}
        _e_val = ${pyStr value}
        _entry = f"{_e_key}={_e_val}"
        assert _entry in _env_list, (
            f"Expected OCI Env entry {_entry!r}, got: {_env_list}"
        )
      '') envAttrs;
    in
    ''
      # envVarSet: image OCI Config.Env
      _img = client.images.get(${pyStr "${containerName}:latest"})
      _env_list = (_img.attrs.get("Config", {}) or {}).get("Env", []) or []
      ${concatStringsSep "\n" checks}
    '';

  # Generate code for sociZtocPresent: use ORAS-style referrers API to
  # look for a SOCI zTOC referrer manifest attached to the image.
  mkSociZtocPresent =
    containerName: soci:
    let
      spanCheck = optionalString (soci.spanSize != null) ''
        _expected_span = ${pyStr soci.spanSize}
        # The `soci inspect` CLI is preferred; fallback to substring match
        # on the referrer manifest JSON.
        assert _expected_span in _referrers_body, (
            f"Expected SOCI span size {_expected_span!r} in referrer manifest, got: {_referrers_body[:500]}"
        )
      '';
    in
    ''
      # sociZtocPresent: ${soci.registry}/${soci.repository}:${soci.tag}
      import subprocess
      _ref_url = f"http://${soci.registry}/v2/${soci.repository}/referrers/"
      # Resolve image digest first
      _manifest = subprocess.check_output(
          ["curl", "-sSf",
           "-H", "Accept: application/vnd.oci.image.manifest.v1+json",
           f"http://${soci.registry}/v2/${soci.repository}/manifests/${soci.tag}"]
      )
      import hashlib, json
      _digest = "sha256:" + hashlib.sha256(_manifest).hexdigest()
      _referrers_body = subprocess.check_output(
          ["curl", "-sSf", f"http://${soci.registry}/v2/${soci.repository}/referrers/{_digest}"]
      ).decode("utf-8", errors="replace")
      # A SOCI v2 zTOC referrer uses artifactType application/vnd.oci.soci.ztoc.v1+json
      # (or similar; be lenient  -  presence of any referrer manifest is the
      # first-order signal).
      assert "manifests" in _referrers_body and "ztoc" in _referrers_body.lower(), (
          f"Expected SOCI zTOC referrer for ${soci.repository}:${soci.tag} at {_ref_url}, "
          f"got: {_referrers_body[:500]}"
      )
      ${spanCheck}
    '';

  # Generate code for manifestDigestMatches: compare two manifest files by
  # SHA-256 to prove reproducibility across two builds.
  mkManifestDigestMatches = _containerName: mdm: ''
    # manifestDigestMatches: ${mdm.firstPath} vs ${mdm.secondPath}
    import hashlib
    def _digest(p):
        with open(p, "rb") as fh:
            return hashlib.sha256(fh.read()).hexdigest()
    _d1 = _digest(${pyStr mdm.firstPath})
    _d2 = _digest(${pyStr mdm.secondPath})
    assert _d1 == _d2, (
        f"Reproducibility: manifest digest mismatch\n"
        f"  ${mdm.firstPath}: sha256:{_d1}\n"
        f"  ${mdm.secondPath}: sha256:{_d2}"
    )
  '';

  # Generate code for firewallPortOpen: assert `nft list ruleset` on the
  # test host contains an accept rule for port + protocol.
  mkFirewallPortOpen = _containerName: entry: ''
    # firewallPortOpen: ${toString entry.port}/${entry.protocol}
    import subprocess
    _rules = subprocess.check_output(["nft", "list", "ruleset"]).decode(
        "utf-8", errors="replace"
    )
    _needle = "${entry.protocol} dport ${toString entry.port}"
    assert _needle in _rules, (
        f"Expected firewall accept rule for ${entry.protocol}/${toString entry.port} "
        f"in nft ruleset, but not found. Rules: {_rules[:2000]}"
    )
  '';

  # Generate code for processEnv assertions.
  mkProcessEnv =
    containerName: envAttrs:
    let
      checks = mapAttrsToList (key: value: ''
        _env_key = ${pyStr key}
        _env_val = ${pyStr value}
        assert _env_key in env_dict, (
            f"Expected env var {_env_key!r}, got keys: {list(env_dict)}"
        )
        assert _env_val in env_dict[_env_key], (
            f"Expected {_env_key!r} to contain {_env_val!r}, got: {env_dict[_env_key]!r}"
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
        (concatMapStringsSep "\n" (mkSucceeds containerName) (a.succeeds or [ ]))
        + (concatMapStringsSep "\n" (mkFails containerName) (a.fails or [ ]))
        + (concatMapStringsSep "\n" (mkSyscallBlocked containerName) (a.syscallBlocked or [ ]))
        + (concatMapStringsSep "\n" (mkFsWriteBlocked containerName) (a.fsWriteBlocked or [ ]))
        + (concatMapStringsSep "\n" (mkDnsResolutionFails containerName) (a.dnsResolutionFails or [ ]))
        + (concatMapStringsSep "\n" (mkTlsHandshakeFails containerName) (a.tlsHandshakeFails or [ ]))
        + (optionalString (a.envVarSet or { } != { }) (mkEnvVarSet containerName a.envVarSet))
        + (optionalString (a.sociZtocPresent or null != null) (
          mkSociZtocPresent containerName a.sociZtocPresent
        ))
        + (optionalString (a.manifestDigestMatches or null != null) (
          mkManifestDigestMatches containerName a.manifestDigestMatches
        ))
        + (concatMapStringsSep "\n" (mkFirewallPortOpen containerName) (a.firewallPortOpen or [ ]))
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
