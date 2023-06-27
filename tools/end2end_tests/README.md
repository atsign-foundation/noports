# tools/end2end_tests

Use this tool to manually test ssh no ports. For example, you may want to test your local repository changes against a release version of ssh no ports, or you may want to test the trunk branch against an old release of ssh no ports, the choice is yours!

Git clone this repository using `git clone`. You will need [Docker](https://docs.docker.com/get-docker/) installed.

You will need to put your atKeys in the `keys/` directory. The keys will be copied over to the container's `~/.atsign/keys` directory. For use, you should put at least two atKeys in that directory; one for the client and one for the server. To get your atKeys, watch this short [2-minute video](https://www.youtube.com/watch?v=tDqrLKSKes8) on our YouTube channel. 

When the docker containers are booted up, there are a few things that the containers come with:

- binaries in `~/.local/bin` == `/atsign/.local/bin` (exception of the blank image)
- reverse ssh tunneling is setup, you can check by running `ssh 0`
- ssh public/private keys in ~/.ssh as "id_ed25519"
- atsign user setup with sudo
- other tools like tmux, nano, nmap, etc.

Read [scripts](#scripts) to learn how to use this tool.

## scripts

To use any of the scripts, ensure you are within the scripts directory; by doing something similar to `cd tools/end2end_tests/scripts`.

### `run.sh`

This script boots up a docker container according to the flags passed.

Usage:

```sh
usage: run.sh
  -h|--help
  -t|--type <type> (required)
  ONE OF THE FOLLOWING (required)
  -l|--local
  -b|--branch <branch/commitid>
  -r|--release <release>
  --blank
```

#### Example:

In one terminal, let's run

```sh
./run.sh -t sshnpd -l
```

Here, we are starting up a container that will build the local repository. The tag is `sshnpd`

In another terminal, let's run

```sh
./run.sh -t sshnp -r 3.2.0
```

Here, we are starting up a container that will build release v3.2.0. The tag is `sshnp`.

With the two containers, we can change directory to `~/.local/bin` and run the binaries to test end to end functionality.

In the sshnpd docker container, we can do something similar to:

```sh
cd ~/.local/bin
./sshnpd -a @bob -m @alice -d docker -s -u -v
```

In the sshnp docker container:

```sh
cd ~/.local/bin
$(./sshnp -f @alice -t @bob -s id_ed25519 -h @rv_am -d docker) 
```

### `clean_local.sh`

This script cleans up the docker mess that `run.sh` creates.

It cleans up:

- containers
- images
- docker networks

## Docker images

- `base/Dockerfile` - base image - closed port 22, atsign user setup with sudo, packages like tmux and nmap, ssh keys ~/.ssh/id_ed25519
- `images/blank/Dockerfile` - blank image, good for testing installer script
- `images/local/Dockerfile` - compiles local repository
- `images/branch/Dockerfile` - compiles a specific branch or commit id
- `images/release/Dockerfile` - downloads a release from github

All images copy `keys/` over to their containers `~/.atsign/keys`

## Notes

- niche thing to remember for `images/local/Dockerfile`: if you ever refactor this tool, double check the keys path directory inside of `images/local/Dockerfile` because that `keys/` directory path is relative to the root of the project, not relative to the scripts directory.
- if you run into errors when trying to docker build (like fetching the metadata of a particular image), try deleting your docker config.json through `rm ~/.docker/config.json`.
