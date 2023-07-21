FROM dart:3.0.5@sha256:65e5f5d6d72ad2f7b32f402c01b5fe8a426455b1ede1e9f840f95a2a8c14afbd AS build-branch

ENV URL=https://github.com/atsign-foundation/sshnoports.git
ENV REPO_DIR=/app/repo
ENV OUTPUT_DIR=/app/output

ARG branch=trunk

RUN set -eux ; \
  mkdir -p ${REPO_DIR} ${OUTPUT_DIR} ; \
  apt-get update ; \
  apt-get install -y git ; \
  cd ${REPO_DIR} ; \
  git clone -b ${branch} --single-branch ${URL} . ; \
  cd packages/sshnoports ; \
  dart pub get ; \
  dart compile exe ${REPO_DIR}/packages/sshnoports/bin/sshnp.dart -o ${OUTPUT_DIR}/sshnp ; \
  dart compile exe ${REPO_DIR}/packages/sshnoports/bin/sshnpd.dart -o ${OUTPUT_DIR}/sshnpd ; \
  dart compile exe ${REPO_DIR}/packages/sshnoports/bin/sshrv.dart -o ${OUTPUT_DIR}/sshrv ; \
  dart compile exe ${REPO_DIR}/packages/sshnoports/bin/sshrvd.dart -o ${OUTPUT_DIR}/sshrvd ; \
  dart compile exe ${REPO_DIR}/packages/sshnoports/bin/activate_cli.dart -o ${OUTPUT_DIR}/at_activate ;

FROM dart:3.0.5@sha256:65e5f5d6d72ad2f7b32f402c01b5fe8a426455b1ede1e9f840f95a2a8c14afbd AS build-local

ENV REPO_DIR=/app/repo
ENV OUTPUT_DIR=/app/output

RUN mkdir -p ${REPO_DIR} ${OUTPUT_DIR} ;

# context must be the same directory as pubspec.yaml
COPY . ${REPO_DIR}

RUN set -eux ; \
  cd ${PKG_DIR} ; \
  cd packages/sshnoports ; \
  dart pub get ; \
  dart compile exe ${REPO_DIR}/packages/sshnoports/bin/sshnp.dart -o ${OUTPUT_DIR}/sshnp ; \
  dart compile exe ${REPO_DIR}/packages/sshnoports/bin/sshnpd.dart -o ${OUTPUT_DIR}/sshnpd ; \
  dart compile exe ${REPO_DIR}/packages/sshnoports/bin/sshrv.dart -o ${OUTPUT_DIR}/sshrv ; \
  dart compile exe ${REPO_DIR}/packages/sshnoports/bin/sshrvd.dart -o ${OUTPUT_DIR}/sshrvd ; \
  dart compile exe ${REPO_DIR}/packages/sshnoports/bin/activate_cli.dart -o ${OUTPUT_DIR}/at_activate ;

FROM debian:stable-20230612-slim@sha256:b09f68bffcf9c14f3105f262e92321d05abaf48460d1f43f884325bcd4395b95 AS build-release

ARG release

ENV BUILD_DIR=/app/build
ENV OUTPUT_DIR=/app/output
ENV URL="https://api.github.com/repos/atsign-foundation/sshnoports/releases/latest"
ENV URLP="https://github.com/atsign-foundation/sshnoports/releases/download"

RUN apt-get update ; \
  apt-get install -y wget dpkg curl ; \
  mkdir -p ${BUILD_DIR} ${OUTPUT_DIR} ; \
  cd ${BUILD_DIR} ; \
  case "$(dpkg --print-architecture)" in \
    amd64) \
      ARCH="x64";; \
    armhf) \
      ARCH="arm";; \
    arm64) \
      ARCH="arm64";; \
    riscv64) \
      ARCH="riscv64";; \
  esac; \
  if [ -z ${release} ]; \
  then \
    LATEST_VERSION=$(curl --silent ${URL} | grep -Po '"tag_name": "v\K.*?(?=")') ; \
    VERSION=${LATEST_VERSION} ; \
  else \
    VERSION=${release} ; \
  fi ; \
  wget "${URLP}/v${VERSION}/sshnp-linux-${ARCH}.tgz" ; \
  tar -xvf sshnp-linux-${ARCH}.tgz ; \
  rm sshnp-linux-${ARCH}.tgz ; \
  cd sshnp ; \
  mv sshnp sshnpd sshrv sshrvd at_activate ${OUTPUT_DIR} ;

FROM debian:stable-20230612-slim@sha256:b09f68bffcf9c14f3105f262e92321d05abaf48460d1f43f884325bcd4395b95 AS base

ENV USER=atsign
ENV HOMEDIR=/${USER}
ENV USER_ID=1024
ENV GROUP_ID=1024

CMD sudo service ssh start

RUN set -eux ; \
  apt-get update ; \
  apt-get install -y openssh-server sudo vim nano iproute2 nmap tmux ; \
  groupadd --gid ${GROUP_ID} ${USER} ; \
  useradd --system --shell /bin/bash --home ${HOMEDIR} --uid ${USER_ID} --gid ${GROUP_ID} ${USER} ; \
  usermod -aG sudo ${USER} ; \
  mkdir -p ${HOMEDIR}/.ssh ${HOMEDIR}/.atsign/keys ${HOMEDIR}/.local/bin ; \
  touch ${HOMEDIR}/.ssh/authorized_keys ; \
  ssh-keygen -t ed25519 -a 100 -f ${HOMEDIR}/.ssh/id_ed25519 -q -N '' ; \
  chown -R ${USER}:${USER} ${HOMEDIR} ; \
  ex +"%s/^%sudo.*$/%sudo ALL=(ALL:ALL) NOPASSWD:ALL/g" -scwq! /etc/sudoers ; \
  sed -E -i 's|^#?(PasswordAuthentication)\s.*|\1 no|' /etc/ssh/sshd_config ; \
  sed -i 's/#ListenAddress 0.0.0.0/ListenAddress 127.0.0.1/g' /etc/ssh/sshd_config ;

FROM base AS runtime-branch

COPY --chown=${USER}:${USER} --from=build-branch /app/output ${HOMEDIR}/.local/bin

WORKDIR ${HOMEDIR}

USER ${USER}

ENTRYPOINT sudo service ssh start && sh ${HOMEDIR}/entrypoint.sh

FROM base AS runtime-release

COPY --chown=${USER}:${USER} --from=build-release /app/output ${HOMEDIR}/.local/bin

WORKDIR ${HOMEDIR}

USER ${USER}

ENTRYPOINT sudo service ssh start && sh ${HOMEDIR}/entrypoint.sh

FROM base AS runtime-local

COPY --chown=${USER}:${USER} --from=build-local /app/output ${HOMEDIR}/.local/bin

WORKDIR ${HOMEDIR}

USER ${USER}

ENTRYPOINT sudo service ssh start && sh ${HOMEDIR}/entrypoint.sh

FROM runtime-branch AS manual-branch

ENTRYPOINT sudo service ssh start && bash

FROM runtime-release AS manual-release

ENTRYPOINT sudo service ssh start && bash

FROM runtime-local AS manual-local

ENTRYPOINT sudo service ssh start && bash

FROM base AS manual-blank

WORKDIR ${HOMEDIR}

RUN set -eux ; \
  apt-get update ; \
  apt-get install -y curl ;

USER ${USER}

ENTRYPOINT sudo service ssh start && bash
