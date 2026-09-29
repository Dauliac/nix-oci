## Purpose

Adds behavioral verification for every tool registered in `oci.pipeline.steps` and for the pipeline machinery itself (step registry, backend routing, gate assembly, CST coherence generator). Today all 15 pipeline tools ship with zero `.test.nix`, so a regression in Rego loading, ignore-file merging, or cosign annotation injection would be invisible to CI.

## ADDED Requirements

### Requirement: Every registered pipeline tool SHALL have at least one behavioral test

For every entry in `oci.pipeline.steps` produced by `step-registrations.nix` (conftest, dockle, dive, syft, trivy-secret, trivy-cve, grype, vulnix, cosign, compliance-trivy, CST, dgoss), there SHALL be at least one BDD scenario that (a) enables the tool for a container, (b) builds or runs the tool's stamp or script, and (c) asserts an observable effect of the tool's core functionality (not merely that the derivation compiles).

#### Scenario: conftest rejects a policy violation
- **WHEN** a container is built with `policy.conftest.enabled = true` and configured to run root (violates built-in `oci.rego`)
- **THEN** the gate build SHALL fail with a Rego violation message
- **AND** when the container is fixed to run non-root, the gate build SHALL succeed

#### Scenario: conftest extraPolicyDirs are merged
- **WHEN** a container is built with `policy.conftest.enabled = true` and `policy.conftest.extraPolicyDirs = [ ./custom-policies ]` where a custom deny rule is triggered
- **THEN** the gate build SHALL fail with the custom rule's deny message

#### Scenario: dockle exit-level gates the build
- **WHEN** a container is built with `lint.dockle.enabled = true` and `lint.dockle.exitLevel = "WARN"`, and dockle finds a WARN-level issue
- **THEN** the gate build SHALL fail
- **AND** with `exitLevel = "FATAL"` for the same image, the gate build SHALL succeed

#### Scenario: dockle ignore list suppresses issues
- **WHEN** dockle emits code CIS-DI-0001 and `lint.dockle.ignore = ["CIS-DI-0001"]` is set
- **THEN** the gate build SHALL succeed

#### Scenario: dive report is generated
- **WHEN** a container is built with `test.dive.enabled = true`
- **THEN** the gate SHALL produce a dive report artifact and the build SHALL fail if efficiency is below a configured threshold

#### Scenario: syft SBOM is a valid CycloneDX document
- **WHEN** a container is built with `sbom.syft.enabled = true`
- **THEN** the gate SHALL produce a CycloneDX JSON document that parses successfully and contains at least one `component` entry

#### Scenario: trivy secret scan flags leaked credentials
- **WHEN** a container includes a file containing an AWS access key pattern and `credentialsLeak.trivy.enabled = true`
- **THEN** the gate build SHALL fail with a trivy secret finding

#### Scenario: trivy CVE scanner runs with ignore file
- **WHEN** the `oci-cve-trivy-<container>` app is executed against a container that has a known CVE and `cve.trivy.ignore.extra` contains that CVE
- **THEN** the app SHALL exit 0 (CVE ignored)
- **AND** without the ignore, the app SHALL exit nonzero

#### Scenario: grype CVE scanner runs
- **WHEN** `oci-cve-grype-<container>` is executed against a container with a known-vulnerable dependency
- **THEN** the app SHALL emit a JSON report containing the CVE ID

#### Scenario: vulnix CVE scanner runs on Nix closure
- **WHEN** `oci-cve-vulnix-<container>` is executed
- **THEN** the app SHALL emit a report referencing the Nix store closure

#### Scenario: cosign keyless signing produces a signature
- **WHEN** a container is pushed and then `oci-cosign-sign-<container>` is executed with `signing.cosign.keyless = true` and `COSIGN_EXPERIMENTAL=1`
- **THEN** the registry SHALL contain a `.sig` referrer for the image manifest
- **AND** the signature SHALL carry the annotations from `signing.cosign.annotations`

#### Scenario: cosign key-based signing produces a signature
- **WHEN** `signing.cosign.key` is set to a test key and `oci-cosign-sign-<container>` is executed
- **THEN** the registry SHALL contain a valid cosign signature verifiable with the corresponding public key

#### Scenario: compliance-trivy CIS check runs
- **WHEN** `oci-compliance-trivy-<container>` is executed with `compliance.trivy.spec = "docker-cis-1.6.0"`
- **THEN** the app SHALL emit a compliance report referencing at least one control ID

#### Scenario: dgoss behavioral test runs
- **WHEN** a container is built with `test.dgoss.enabled = true` and a goss file that asserts port 8080 is listening
- **THEN** the app SHALL exit 0 when the container has an entrypoint bound to 8080 and nonzero when it doesn't

### Requirement: CST coherence generator SHALL round-trip user config to metadataTest JSON

`mkCoherenceCst` SHALL generate a metadataTest JSON that reflects the container's declared user, entrypoint, ports, labels, env, workingDir, and volumes. A test SHALL exercise each field and confirm the generated JSON matches the declared value.

#### Scenario: Declared port appears in coherence output
- **WHEN** a container is built with `ports = ["8080:80"]` and `test.containerStructureTest.coherence = true`
- **THEN** the generated metadataTest JSON SHALL contain `exposedPorts` including `"80"`

#### Scenario: Declared entrypoint appears
- **WHEN** a container is built with `entrypoint = ["/bin/myapp" "--flag"]`
- **THEN** the generated metadataTest JSON SHALL contain `entrypoint = ["/bin/myapp", "--flag"]`

#### Scenario: Declared user labels appear
- **WHEN** a container is built with `labels = { "org.example.owner" = "team-x"; }`
- **THEN** the generated metadataTest JSON SHALL contain that label

#### Scenario: Declared workingDir appears
- **WHEN** a container is built with `workingDir = "/srv"`
- **THEN** the generated metadataTest JSON SHALL contain `workdir = "/srv"`

#### Scenario: Empty fields are omitted, not null
- **WHEN** a container is built with no explicit ports
- **THEN** the generated metadataTest JSON SHALL not contain an `exposedPorts` key (rather than `exposedPorts: null` or `[]`)

### Requirement: Pipeline machinery SHALL be verified end-to-end

The step registry, `defaultBackend` toggle, `mkStamp` / `mkScript` wiring, and gate assembly SHALL each have a test that confirms the expected outputs are produced when steps are enabled.

#### Scenario: Enabled step contributes a stamp
- **WHEN** a container enables a step whose `mkStamp` is defined and non-null
- **THEN** the container's gate derivation SHALL depend on that stamp (visible in `nix-store -q --references`)

#### Scenario: Enabled step contributes a script
- **WHEN** a container enables a step whose `mkScript` is defined
- **THEN** a corresponding flake app SHALL be exposed for that container

#### Scenario: defaultBackend = "vm" routes probes to gate
- **WHEN** `oci.pipeline.defaultBackend = "vm"` and a probe step is enabled
- **THEN** the probe SHALL contribute a stamp to the gate (not just an app)

#### Scenario: defaultBackend = "daemon" routes probes to apps
- **WHEN** `oci.pipeline.defaultBackend = "daemon"` and a probe step is enabled
- **THEN** the probe SHALL contribute only a flake app (no gate stamp)

#### Scenario: Per-step backend override wins over defaultBackend
- **WHEN** `defaultBackend = "vm"` but a specific step is registered with `backend = "daemon"`
- **THEN** that step SHALL be routed to an app, not to the gate

#### Scenario: User-registered step is accepted
- **WHEN** a user contributes an additional step via `oci.pipeline.steps.myTool = { phase = ...; category = ...; backend = ...; mkStamp = ...; }`
- **THEN** the step SHALL be composed into the gate exactly like a built-in step
