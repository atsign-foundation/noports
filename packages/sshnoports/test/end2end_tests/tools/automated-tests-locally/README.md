# How to run this automated end-to-end tests locally

## Prerequisites

- [Git](https://git-scm.com/downloads)
- [Docker Desktop](https://docs.docker.com/get-docker/) which already contains [Docker Compose](https://docs.docker.com/compose/install/)
- [3 atSigns](my.atsign.com/go) and their [.atKeys files](https://www.youtube.com/watch?v=tDqrLKSKes8)

## Running the Tests

You can either set up everything [manually](#manually) or use the [shell script](#with-the-shell-script) to which sets up and runs everything for you manually.

### With the Shell Script

Everything you need to do to set up the automated tests [manually](#manually) are done for you with the shell script.

1. Clone the repository

```sh
git clone https://github.com/atsign-foundation/sshnoports.git
```

2. Change directory into `automated-tests-locally`

```sh
cd test/end2end_tests/tools/automated-tests-locally
```

3. Run the `run-local.sh` script

```sh
./run-local.sh 
```

### Manually

1. Clone this repository

```sh
git clone https://github.com/atsign-foundation/sshnoports.git
```

2. Add your keys

## Troubleshooting

- If you get 'permission denied' error when trying to run the scripts, you may need to do something similar to: `chmod -R 777 ./configuration/`
- If you get a 'load metadata for docker.io/...' error when building the docker images, you can try running `rm ~/.docker/config.json` and then try again.