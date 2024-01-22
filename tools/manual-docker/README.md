# SSH No Ports - Manual Testing Tool using Docker

You may find yourself sometimes trying to test your development on ssh no ports against a particular version or branch. That is where the manual testing tool comes to help. Using the docker-compose.yamls or the bash script provided, you can spin up multiple docker containers containing the right ssh no ports binaries that you want to test.

Currently, you can build and run the following docker image targets:

- blank (no sshnp binaries, just sshd running)
- branch (sshnp binaries from a particular branch name or commit id, e.g. trunk)
- local (sshnp binaries from your current local source code)
- release (sshnp binaries from a particular ssh no ports release, e.g. 3.3.0)

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- Atsigns from [my.atsign.com/go](https://my.atsign.com/go) and their [.atKeys](https://www.youtube.com/watch?v=tDqrLKSKes8) files

## Using the Tool

You can use the tool with [docker commands manually](#using-docker-commands) or with the [custom shell script](#using-the-custom-shell-script) provided to make running the docker commands easier.

### Using the custom shell script

To use the shell script, you need to be able to run shell scripts. If you're on MacOS or Linux, you should be able to run them just fine by doing something similar to:

```
./run-manual-docker.sh
```

However, you may need to `chmod +x run-manual-docker.sh` to give yourself permission to run the script.

If you are on Windows, you may need to use [WSL]().

1. Clone this repository

```sh
git clone https://github.com/atsign-foundation/noports.git
```

2. Navigate to the `tools` directory

```sh
cd tests/end2end_tests/tools
```

3. Use the script

```sh
$ ./run-manual-docker.sh

usage: ./run-manual-docker.sh
  -h|--help
  -t|--tag <sshnp/sshnpd/srvd> (required) - docker container tag
  --no-cache (optional) - docker build without cache
  --rm (optional) - remove container after exit
  ONE OF THE FOLLOWING (required)
  -l|--local - build from local source
  -b|--branch <branch/commitid> - build from branch/commitid
  -r|--release [release] - build from a sshnoports release, latest release by default
  --blank - build container with no binaries

  example: ./run-manual-docker.sh -t sshnp -b trunk
  example: ./run-manual-docker.sh -t sshnpd -l
  example: ./run-manual-docker.sh -t srvd -r v3.3.0
  example: ./run-manual-docker.sh -t sshnp --release
  example: ./run-manual-docker.sh -t sshnp --blank
```

4. Example: spin up a container to run sshnp on latest release

```
./run-manual-docker.sh -t sshnp --release
```

5. Another example: spin up a container with the intention to run sshnpd on a particular commit id

```
./run-manual-docker.sh -t sshnpd --branch 1234567890
```

### Using Docker Commands

If you do not want to use the [custom shell script](#using-the-custom-shell-script), you can use the docker commands manually.

1. Clone this repository

```sh
git clone https://github.com/atsign-foundation/noports.git
```

2. Navigate to the `tools` directory

```sh
cd tests/end2end_tests/tools/manual-tool
```

3. Change directory into the image you want to build and run the appropriate docker compose commands.

Example: build and run a container to run sshnp on a particular release

```
cd release
sudo docker-compose build --build-arg release=v3.3.0
sudo docker-compose run --rm -it container-sshnp
```

Example: build and run a container to run sshnpd on latest trunk

```
cd branch
sudo docker-compose build --build-arg branch=trunk
sudo docker-compose run --rm -it container-sshnpd
```

The `--rm` will delete the container once finished with