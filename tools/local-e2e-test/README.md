# SSH No Ports - Automated End-to-End Testing Using Docker

You may find yourself sometimes trying to test your development on ssh no ports against a particular version or branch. That is where the manual testing environment comes to help. Using a tool called act, we are able to simulate a GitHub Actions environmentally locally through docker.

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- Atsigns from [my.atsign.com/go](https://my.atsign.com/go) and their [.atKeys](https://www.youtube.com/watch?v=tDqrLKSKes8) files
- [nektos/act](https://github.com/nektos/act)

## Using the Tool

It is recommended that you use the provided shell tool to run act.

### Using the shell tool

To use the shell script, you need to be able to run shell scripts. If you're on MacOS or Linux, you should be able to run them just fine by doing something similar to:

```
./run-act.sh
```

However, you may need to `chmod +x run-act.sh` to give yourself permission to run the script.

If you are on Windows, you may need to use [WSL]().

1. Clone this repository

```sh
git clone https://github.com/atsign-foundation/sshnoports.git
```

2. Navigate to the `tools` directory

```sh
cd tests/end2end_tests/tools
```

3. Use the script

```sh
$ ./run-act.sh
```

#### Important Notes about the environment

If there is a test failure in the act environment, then the container is intentionally left on the machine for observability.


Due to limitations of act, and the way this environment was configured, only one job may be run at a time:
  - Running multiple will lead to a race condition, since the docker-compose.yaml file (created locally) will be shared by all containers
  - This will be solved once the maintainers of act implement [strategy.job-index](https://github.com/nektos/act/issues/1975)


To run a different variation edit the following lines within [run-act.sh](./run-act.sh)
```sh
--job e2e_test \
--matrix np:local \
--matrix npd:local \
```
Note that `--matrix` will only match and run matrix configurations which already exist in the workflow, it will not create new configurations.