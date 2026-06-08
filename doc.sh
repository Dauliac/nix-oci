#!/usr/bin/env bash
set -euo pipefail

nix build .#legacyPackages.x86_64-linux.docs --out-link result-docs
rm -rf toto
cp -rL result-docs toto
chmod -R u+w toto
rm -f result-docs
