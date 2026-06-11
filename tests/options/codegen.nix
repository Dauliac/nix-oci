# Pytest codegen — translates _tests specs into Python test files.
#
# Each test spec produces a test_<name>.py file with test functions
# generated from declarative assertions. Uses docker SDK via fixtures
# from conftest.py.
{ lib }:
let
  # Sanitize test name for Python identifier (- → _)
  pyName = name: builtins.replaceStrings [ "-" ] [ "_" ] name;

  # Generate a single test_<name>.py file from a spec.
  mkTestFile =
    testName: spec:
    let
      on = pyName testName;
      imageDefault = "test-${testName}-default:latest";
      imageOverride = "test-${testName}-override:latest";
      a = spec.assertions;

      # ── Image config assertions ──────────────────────────────
      imageConfigTests = lib.optionalString (a.imageConfig != { }) ''
        def test_${on}_override_image_config(image_helper):
            h = image_helper("${imageOverride}")
            h.assert_config(${builtins.toJSON a.imageConfig})
      '';

      # ── Label assertions ─────────────────────────────────────
      labelTests = lib.optionalString (a.labels != { }) ''
        def test_${on}_override_labels(image_helper):
            h = image_helper("${imageOverride}")
            h.assert_labels(${builtins.toJSON a.labels})
      '';

      # ── File content assertions ──────────────────────────────
      fileContainsTests = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          path: expected:
          let
            safePath = builtins.replaceStrings [ "/" "." ] [ "_" "_" ] path;
          in
          ''
            def test_${on}_override_file${safePath}_contains(image_helper):
                h = image_helper("${imageOverride}")
                h.assert_file_contains(${builtins.toJSON path}, ${builtins.toJSON expected})
          ''
        ) a.fileContains
      );

      fileNotContainsTests = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          path: excluded:
          let
            safePath = builtins.replaceStrings [ "/" "." ] [ "_" "_" ] path;
          in
          ''
            def test_${on}_override_file${safePath}_not_contains(image_helper):
                h = image_helper("${imageOverride}")
                h.assert_file_not_contains(${builtins.toJSON path}, ${builtins.toJSON excluded})
          ''
        ) a.fileNotContains
      );

      # ── Oneshot run assertions ───────────────────────────────
      succeedsTests = lib.concatImapStringsSep "\n" (
        i: e:
        let
          safeCmd = builtins.replaceStrings [ "/" "-" " " ] [ "_" "_" "_" ] e.command;
        in
        ''
          def test_${on}_override_succeeds_${safeCmd}(container_runner):
              r = container_runner("${imageOverride}")
              r.run_succeeds(${builtins.toJSON e.command}, args=${builtins.toJSON e.args}${
                lib.optionalString (e.stdout != null) ", stdout=${builtins.toJSON e.stdout}"
              })
        ''
      ) a.succeeds;

      failsTests = lib.concatImapStringsSep "\n" (
        i: e:
        let
          safeCmd = builtins.replaceStrings [ "/" "-" " " ] [ "_" "_" "_" ] e.command;
        in
        ''
          def test_${on}_override_fails_${safeCmd}(container_runner):
              r = container_runner("${imageOverride}")
              r.run_fails(${builtins.toJSON e.command}, args=${builtins.toJSON e.args}${
                lib.optionalString (e.exitCode != null) ", exit_code=${toString e.exitCode}"
              })
        ''
      ) a.fails;

      # ── HTTP assertions ──────────────────────────────────────
      httpTests = lib.optionalString (a.httpResponds != null) ''
        import requests
        from tenacity import retry, stop_after_delay, wait_fixed

        @retry(stop=stop_after_delay(30), wait=wait_fixed(1), reraise=True)
        def _wait_http_${on}():
            resp = requests.get("http://localhost:${toString a.httpResponds.port}${a.httpResponds.path}")
            resp.raise_for_status()
            return resp

        def test_${on}_override_http_responds():
            resp = _wait_http_${on}()
            ${lib.optionalString (a.httpResponds.contains != "")
              ''assert ${builtins.toJSON a.httpResponds.contains} in resp.text, f"Expected ${builtins.toJSON a.httpResponds.contains} in response: {resp.text[:300]}"''
            }
      '';

      # ── Process env assertions ───────────────────────────────
      envTests = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (key: contains: ''
          def test_${on}_override_env_${pyName key}(daemon_helper):
              d = daemon_helper("test-${testName}-override", "${imageOverride}")
              d.assert_env(${builtins.toJSON key}, ${builtins.toJSON contains})
        '') a.processEnv
      );

      # ── Container inspect assertions ─────────────────────────
      inspectTests = lib.optionalString (a.containerInspect != { }) ''
        def test_${on}_override_inspect(daemon_helper):
            d = daemon_helper("test-${testName}-override", "${imageOverride}")
            d.assert_inspect(${builtins.toJSON a.containerInspect})
      '';

      # ── Systemd assertions ───────────────────────────────────
      systemdTests = lib.optionalString (a.systemdProps != { }) ''
        import subprocess

        def test_${on}_override_systemd():
            props = subprocess.check_output([
                "systemctl", "show",
                "podman-test-${testName}-override.service",
                "--property=${lib.concatStringsSep "," (builtins.attrNames a.systemdProps)}",
            ], text=True)
            expected = ${builtins.toJSON a.systemdProps}
            for key, value in expected.items():
                assert f"{key}={value}" in props, (
                    f"Expected {key}={value} in systemd props: {props}"
                )
      '';

      # ── Escape hatch ─────────────────────────────────────────
      runtimeTests = lib.optionalString (a.runtime != "") ''
        def test_${on}_override_runtime(client, image_helper, container_runner, daemon_helper):
            h = image_helper("${imageOverride}")
            r = container_runner("${imageOverride}")
            ${a.runtime}
      '';

      # ── Default container: just check image loads ────────────
      defaultTest = ''
        def test_${on}_default_image_exists(client):
            """Default container image loads successfully."""
            client.images.get("${imageDefault}")
      '';

      hasContent =
        a.imageConfig != { }
        || a.labels != { }
        || a.fileContains != { }
        || a.fileNotContains != { }
        || a.succeeds != [ ]
        || a.fails != [ ]
        || a.httpResponds != null
        || a.processEnv != { }
        || a.containerInspect != { }
        || a.systemdProps != { }
        || a.runtime != "";
    in
    ''
      """Generated tests for option: ${testName} (level: ${spec.level})"""

      ${defaultTest}

      ${lib.optionalString hasContent (
        lib.concatStringsSep "\n\n" (
          builtins.filter (s: s != "") [
            imageConfigTests
            labelTests
            fileContainsTests
            fileNotContainsTests
            succeedsTests
            failsTests
            httpTests
            envTests
            inspectTests
            systemdTests
            runtimeTests
          ]
        )
      )}
    '';

  # Generate the full test suite as a derivation containing .py files.
  mkTestSuite =
    pkgs: allTests:
    pkgs.runCommand "option-test-suite" { } (
      ''
        mkdir -p $out
        cp ${../options/conftest.py} $out/conftest.py
      ''
      + lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: spec: ''
          cat > $out/test_${pyName name}.py << 'PYTEST_EOF'
          ${mkTestFile name spec}
          PYTEST_EOF
        '') allTests
      )
    );
in
{
  inherit mkTestFile mkTestSuite;
}
