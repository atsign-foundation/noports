# tools/end2end_tests

Use this tool to test the end to end functionality of ssh no ports. For example, you may want to test your local repository changes against a release version of ssh no ports, or you may want to test the trunk branch against an old release of ssh no ports, the choice is yours!

Read [scripts](#scripts) to learn how to use this tool.

## scripts

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

## Docker images

- `base/Dockerfile` - base image - closed port 22, atsign user setup with sudo, packages like tmux and nmap, ssh keys ~/.ssh/id_ed25519
- `images/blank/Dockerfile` - blank image, good for testing installer script
- `images/local/Dockerfile` - compiles local repository
- `images/branch/Dockerfile` - compiles a specific branch or commit id
- `images/release/Dockerfile` - downloads a release from github

## Notes

- niche thing to remember for `images/local/Dockerfile`: if you ever refactor this tool, double check the keys path directory inside of `images/local/Dockerfile` because that `keys/` directory path is relative to the root of the project, not relative to the scripts directory.

