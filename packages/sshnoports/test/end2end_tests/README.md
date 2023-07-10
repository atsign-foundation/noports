# sshnoports/packages/test/end2end_tests

## Tour

There's a lot going on here. Here's a quick tour:

- `contexts/` - files and folders that Docker containers interact with via volumes
- `image/` - the Docker image with multiple targets. Read more on this [here](#dockerfile-image)
- `templates/` - templates for the entrypoints that the containers use
- `tools/` - tools for testing sshnoports 1. automated locally, 2. manually locally, 3. configuration scripts that CI uses
- `tests/` - contains the docker compose files to run the end2end services

## Running Containers Manually Locally

You can interact with a set of built ssh no ports binaries manually using the [manual-tool](tools/manual-tool/README.md). This is useful if you want to run the ssh no ports binaries yourself.

## Running Containers Automatically Locally

You can run the automated tests that CI does, but locally. Read more on [automated-tests-locally](tools/automated-tests-locally/README.md).

## Dockerfile Image

This Dockerfile contains multiple stages:

- `build-branch` - used by runtime-branch, contains sshnoports built binaries from a specified branch in `/output`
- `build-release` - used by runtime-release, contains sshnoports built binaries from a specified release in `/output`
- `build-local` - used by runtime-local, contains sshnoports built binaries from the local machine in `/output`
- `base` - Docker base image, various necessities like closed port 22, sshd, `atsign` user set up, and more
- `runtime-branch` - contains sshnoports binaries from a specified branch in `/atsign/.local/bin` and runs `/atsign/entrypoint.sh` specify branch with `--build-arg branch=trunk` when using docker build
- `runtime-release` - contains sshnoports binaries from a specified release in `/atsign/.local/bin` and runs `/atsign/entrypoint.sh`. specify release with `--build-arg release=3.3.0` when using docker build
- `runtime-local` - contains sshnoports binaries from the local machine in `/atsign/.local/bin` and runs `/atsign/entrypoint.sh`
- `manual-branch` - contains sshnoports binaries from a specified branch in `/atsign/.local/bin` and runs bash
- `manual-blank` - no binaries, runs bash, useful for testing ssh no ports installers via curl
- `manual-release` - contains sshnoports binaries from a specified release in `/atsign/.local/bin` and runs bash
- `manual-local` - contains sshnoports binaries from the local machine in `/atsign/.local/bin` and runs bash