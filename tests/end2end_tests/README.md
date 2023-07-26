# sshnoports/packages/test/end2end_tests

There are two main things happening in this folder that you can use for testing stuff locally:

1. [Running Containers Automatically Locally](#running-containers-automatically-locally)
2. [Running Containers Manually Locally](#running-containers-manually-locally)

Then there's automated testing stuff that can be found in `tests/` and `tools/configuration/`. Read `.github/workflows/end2end_tests.yaml` to learn more.

## Tour

There's a lot going on here. Here's a quick tour:

- `contexts/` - files and folders that Docker containers interact with via volumes
- `image/` - the Docker image with multiple targets. Read more on this [here](#dockerfile-image)
- `templates/` - templates for the entrypoints that the containers use
- `tests/` - contains the docker compose files to run the end2end services
- `tools/` - tools for testing sshnoports 1. automated locally, 2. manually locally, 3. configuration scripts that CI uses
- `utility/` - contains the utility compose files that may prove useful for testing

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