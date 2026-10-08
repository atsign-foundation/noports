# tests/e2e_all/dockerfiles

- [tests/e2e_all/dockerfiles](#tests-e2e-all-dockerfiles)
  * [Dockerfile.c.branch](#dockerfilecbranch)
    + [1. From Commit Hash](#1-from-commit-hash-1)
    + [2. From Branch Name](#2-from-branch-name-1)
  * [Dockerfile.c.current](#dockerfileccurrent)
    + [1. From Root Directory](#1-from-root-directory)
  * [Dockerfile.c.release](#dockerfilecrelease)
    + [1. From Release Version](#1-from-release-version-1)
  * [Dockerfile.dart.branch](#dockerfiledartbranch)
    + [1. From Commit Hash](#1-from-commit-hash)
    + [2. From Branch Name](#2-from-branch-name)
  * [Dockerfile.dart.current](#dockerfiledartcurrent)
    + [1. From Root Directory](#1-from-root-directory-1)
  * [Dockerfile.dart.release](#dockerfiledartrelease)
    + [1. From Release Version](#1-from-release-version)
    + [2. From Latest Version](#2-from-latest-version)

## Dockerfile.c.branch

Here are some examples of building a Docker image with C binaries.

### 1. From Commit Hash

```bash
commit_hash=$(git rev-parse HEAD)
echo "Latest commit hash: $commit_hash"

sudo docker build \
    -f Dockerfile.c.branch \
    -t noports-c:$commit_hash \
    --build-arg branch=$commit_hash \
    --target runtime \
    .

sudo docker run \
    --rm \
    -it \
    -v ~/.atsign/keys/:/atsign/.atsign/keys/ \
    noports-c:$commit_hash \
    /bin/bash -c "sudo service ssh start && /usr/local/bin/sshnpd -a @12snowboating -m @12alpaca -d c-test -s -v"
```

### 2. From Branch Name

```bash
branch=trunk

sudo docker build \
    -f Dockerfile.c.branch \
    -t noports-c:$branch \
    --build-arg branch=$branch \
    --target runtime \
    .

sudo docker run \
    --rm \
    -it \
    -v ~/.atsign/keys/:/atsign/.atsign/keys/ \
    noports-c:$branch \
    /bin/bash -c "sudo service ssh start && /usr/local/bin/sshnpd -a @12snowboating -m @12alpaca -d c-trunk -s -v"
```

## Dockerfile.c.current

Here are some examples of building a Docker image containing C binaries from the current repository as it is

### 1. From Root Directory

Ensure that `pwd` is the root directory of the repository.

```bash
sudo docker build \
    -f tests/e2e_all/dockerfiles/Dockerfile.c.current \
    -t noports-c:current \
    --target runtime \
    .
```

Running an ephemeral container with the current C binaries:

```bash
sudo docker run \
    --rm \
    -it \
    -v ~/.atsign/keys/:/atsign/.atsign/keys/ \
    noports-c:current \
    /bin/bash -c "sudo service ssh start && /usr/local/bin/sshnpd -a @12snowboating -m @12alpaca -d c-current -s -v"
```

Another way of doing the same thing but with `-d`:

```bash
sudo docker run \
    --rm \
    -d \
    -v ~/.atsign/keys/:/atsign/.atsign/keys/ \
    noports-c:current \
    /bin/bash -c "sudo service ssh start && /usr/local/bin/sshnpd -a @12snowboating -m @12alpaca -d c-current -s -v"
```

Interactive container method using `-it`:

```bash
sudo docker run \
    --rm \
    -it \
    -v ~/.atsign/keys/:/atsign/.atsign/keys/ \
    noports-c:current \
    /bin/bash
```

## Dockerfile.c.release

Here are some examples of running a Docker image with C binaries.

### 1. From Release Version

```bash
release=c1.0.0

sudo docker build \
    -f ./Dockerfile.c.release \
    -t noports-c:$release \
    --build-arg release=$release \
    --target runtime \
    .

sudo docker run \
    --rm \
    -it \
    -v ~/.atsign/keys/:/atsign/.atsign/keys/ \
    noports-c:$release \
    /bin/bash -c "sudo service ssh start && /usr/local/bin/sshnpd -a @12snowboating -m @12alpaca -d c101 -s -u -v"
```

## Dockerfile.dart.branch

Below are some examples for building a Docker image with Dart binaries.

### 1. From Commit Hash

```bash
commit_hash=$(git rev-parse HEAD)
echo "Latest commit hash: $commit_hash"

sudo docker build \
    -f Dockerfile.dart.branch \
    -t noports-dart:$commit_hash \
    --build-arg branch=$commit_hash \
    --target runtime \
    .

sudo docker run \
    --rm \
    -it \
    -v ~/.atsign/keys/:/atsign/.atsign/keys/ \
    noports-dart:$release \
    /bin/bash -c "sudo service ssh start && /usr/local/bin/sshnpd -a @12snowboating -m @12alpaca -d dart-latest-hash -s -v"
```

### 2. From Branch Name

```bash
branch="trunk"

sudo docker build \
    -f Dockerfile.dart.branch \
    -t noports-dart:$branch \
    --build-arg branch=$branch \
    --target runtime \
    .

sudo docker run \
    --rm \
    -it \
    -v ~/.atsign/keys/:/atsign/.atsign/keys/ \
    noports-dart:$branch \
    /bin/bash -c "sudo service ssh start && /usr/local/bin/sshnpd -a @12snowboating -m @12alpaca -d dart-trunk -s -v"
```

## Dockerfile.dart.current

Here are some examples of building a Docker image containing Dart binaries from the current repository as it is

### 1. From Root Directory

Ensure that `pwd` is the root directory of the repository.

```bash
sudo docker build \
    -f tests/e2e_all/dockerfiles/Dockerfile.dart.current \
    -t noports-dart:current \
    --target runtime \
    .
```

Running an ephemeral interactive container:

```bash
sudo docker run \
    --rm \
    -it \
    -v ~/.atsign/keys/:/atsign/.atsign/keys/ \
    noports-dart:current \
    /bin/bash -c "sudo service ssh start && /bin/bash"
```

## Dockerfile.dart.release

Here are some examples of running a Docker image with Dart binaries.

### 1. From Release Version

```bash
release=v5.8.7

sudo docker build \
    -f ./Dockerfile.dart.release \
    -t noports-dart:$release \
    --build-arg release=$release \
    --target runtime \
    .

sudo docker run \
    --rm \
    -it \
    -v ~/.atsign/keys/:/atsign/.atsign/keys/ \
    noports-dart:$release \
    /bin/bash -c "sudo service ssh start && /usr/local/bin/sshnp -f @12alpaca -t @12snowboating -r @rv_am -d c101 -o '-o StrictHostKeyChecking=no' -v -s -i ~/.ssh/id_ed25519"
```

### 2. From Latest Version

```bash
release=latest

sudo docker build \
    -f ./Dockerfile.dart.release \
    -t noports-dart:$release \
    --build-arg release=$release \
    --target runtime \
    .

sudo docker run \
    --rm \
    -it \
    -v ~/.atsign/keys/:/atsign/.atsign/keys/ \
    noports-dart:$release \
    /bin/bash -c "sudo service ssh start && /usr/local/bin/sshnpd -a @12snowboating -m @12alpaca -d dart-latest -s -v"
```
