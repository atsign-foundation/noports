#!/usr/bin/env bash

# Script dependencies:
# - docker
# - flatpak
# - flatpak-builder

set -eux

script_dir="$(dirname -- "$(readlink -f -- "$0")")"

cd "$script_dir" || exit 1
flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install -y --user flathub org.freedesktop.Sdk/x86_64/24.08
flatpak install -y --user flathub org.freedesktop.Sdk.Extension.llvm19/x86_64/24.08
docker run --rm -v "$script_dir":/usr/src/flatpak -u $(id -u):$(id -g) theappgineer/flatpak-flutter:latest flatpak-flutter.yaml

source .venv/bin/activate

flatpak-builder --force-clean --user --install .flatpak-builder com.atsign.NoPortsDesktop.yaml
