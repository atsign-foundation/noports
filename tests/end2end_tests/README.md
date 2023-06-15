# end2end_tests

<!-- TODO -->

## Scripts

The `scripts/` directory contains scripts to test the end-to-end functionality of the project on your local machine.

You will need [Docker](https://www.docker.com/) installed on your machine.

- `build_local_base.sh` - Builds the base image for the project.
- `clean_local.sh` - Cleans up your local Docker environment of any images, containers, and networks created by the scripts.
- `run_specific.sh` - Runs a particular docker container (sshnp, sshnpd, sshrvd)