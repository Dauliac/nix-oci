+++
title = "Image signing & provenance"
description = "Cryptographic image signing with cosign and Sigstore: keyless signing, key-based signing, annotations, verification, and policy enforcement"
+++

# Image signing & provenance

nix-oci integrates **cosign** (part of the Sigstore project) for
cryptographic image signing. Signatures prove that your CI pipeline built
the image and that nobody tampered with it in the registry.

## Keyless signing (default)

By default, cosign uses **keyless signing** via Sigstore's Fulcio CA.
The signer authenticates via an OIDC provider (GitHub Actions, Google,
Microsoft), receives an ephemeral certificate, and signs the image.
Rekor (Sigstore's public transparency log) records the signature and
certificate. No key management required.

## Key-based signing

For air-gapped or compliance-constrained environments, see
[`oci.signing.cosign`](../../../reference/flake-parts-options.html):

```nix
oci.signing.cosign = {
  enabled = true;
  keyless = false;
  key = "awskms://arn:aws:kms:eu-west-1:123456789:key/abcd-1234";
  # Or: "env://COSIGN_PRIVATE_KEY", "./cosign.key", "hashivault://mykey"
};
```

## Annotations and verification

```nix
oci.signing.cosign = {
  enabled = true;
  annotations = {
    "repo" = "https://github.com/example/repo";
    "build-system" = "nix";
  };
  verify = true;  # verify signature immediately after signing
  certificateIdentityRegexp = "https://github.com/myorg/.*";
  certificateOidcIssuerRegexp = "https://token.actions.githubusercontent.com";
};
```

## Running signing

The signing script takes the pushed image reference as argument:

```bash
nix run .#sign-cosign-my-app -- registry.example.com/my-app:v1.0.0

# With specific digest (recommended for CI)
nix run .#sign-cosign-my-app -- registry.example.com/my-app:v1.0.0 sha256:abc123...
```

## Policy enforcement

You can enforce signed images at admission time using:

- **Kyverno** `verifyImages` policies
- **OPA/Gatekeeper** with cosign verification
- **Kubernetes ImagePolicyWebhook**

The annotations attached during signing are available in policy
evaluation, enabling rules like "only deploy images signed by our CI
with `build-system=nix`".
