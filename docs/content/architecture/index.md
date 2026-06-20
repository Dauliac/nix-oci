+++
title = "Architecture & design"
description = "Design decisions, OCI standards compliance, archive-less building, and how nix-oci derives metadata from NixOS service definitions"

+++

# Architecture & design

nix-oci makes deliberate architectural choices that differ from
traditional container tooling. These pages explain why.

## Topics

- [Design choices](design-choices.html)
  — why Nix for containers, module system as policy engine,
  one-file-per-option pattern

- [OCI standards compliance](oci-standards-compliance.html)
  — how nix-oci adheres to the OCI image and distribution specs

- [Archive-less container building](archive-less-container-building.html)
  — how nix2container avoids tar archives entirely

- [Container metadata wiring](container-metadata-wiring.html)
  — how NixOS service definitions flow into OCI image config

- [Automatic labeling](automatic-labeling.html)
  — auto-generated OCI annotations, K8s PSS hints, build metadata

- [Automatic metadata](automatic-metadata.html)
  — healthchecks, stop signals, volumes, working directory
  derived from systemd services
