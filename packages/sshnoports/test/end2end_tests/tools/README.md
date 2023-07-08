# SSH No Ports - Manual Testing Tool using Docker

You may find yourself sometimes trying to test your development on ssh no ports against a particular version or branch. That is where the manual testing tool comes to help. Using the docker-compose.yamls or the bash script provided, you can spin up multiple docker containers containing the right ssh no ports binaries that you want to test.

Currently, you can build and run the following docker image targets:

- blank (no sshnp binaries, just sshd running)
- branch (sshnp binaries from a particular branch name or commit id, e.g. trunk)
- local (sshnp binaries from your current local source code)
- release (sshnp binaries from a particular ssh no ports release, e.g. 3.3.0)

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
<!-- TODO atKeys in contexts/ -->

## Using the Tool

### Using Docker Commands

<!-- TODO -->

### Using the custom shell script

TO use the shell script, you need to be able to run shell scripts. If you're on MacOS or Linux, you should be able to run them just fine by doing something similar to:

```
./run.sh
```

However, you may need to `chmod +x run.sh` to give yourself permission to run the script.

If you are on Windows, you may need to use [WSL]().

<!-- TODO -->

