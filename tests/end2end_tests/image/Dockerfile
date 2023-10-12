# BASE
FROM debian:stable-20231009-slim@sha256:8cfbea7c925801b678943e59e3ae6fc5b925e8bfe0243f4e724e180edb5aabcd AS base

ENV USER=atsign
ENV HOMEDIR=/${USER}
ENV USER_ID=1024
ENV GROUP_ID=1024

CMD sudo service ssh start

RUN set -eux ; \
  apt-get update ; \
  apt-get install -y openssh-server sudo vim nano iproute2 nmap tmux curl cron ; \
  groupadd --gid ${GROUP_ID} ${USER} ; \
  useradd --system --shell /bin/bash --home ${HOMEDIR} --uid ${USER_ID} --gid ${GROUP_ID} ${USER} ; \
  usermod -aG sudo ${USER} ; \
  mkdir -p ${HOMEDIR}/.ssh ${HOMEDIR}/.atsign/keys ${HOMEDIR}/.local/bin ; \
  touch ${HOMEDIR}/.ssh/authorized_keys ; \
  ssh-keygen -t ed25519 -a 100 -f ${HOMEDIR}/.ssh/id_ed25519 -q -N '' ; \
  chmod 600 ${HOMEDIR}/.ssh/id_ed25519* ; \
  chown -R ${USER}:${USER} ${HOMEDIR} ; \
  ex +"%s/^%sudo.*$/%sudo ALL=(ALL:ALL) NOPASSWD:ALL/g" -scwq! /etc/sudoers ; \
  sed -E -i 's|^#?(PasswordAuthentication)\s.*|\1 no|' /etc/ssh/sshd_config ; \
  sed -i 's/#ListenAddress 0.0.0.0/ListenAddress 127.0.0.1/g' /etc/ssh/sshd_config ;
# END BASE

# BRANCH
# BUILD BRANCH
FROM dart:3.1.3@sha256:b42328ca91e961fdec1346e930df42fb027d51cfba04af2a748764bbc867e1f8 AS build-branch

ENV URL=https://github.com/atsign-foundation/sshnoports.git
ENV REPO_DIR=/app/repo
ENV PACKAGE_DIR=${REPO_DIR}/packages/sshnoports
ENV OUTPUT_DIR=/app/output

ARG branch=trunk

# Builds using the noports_core package available on the branch specified
RUN set -eux ; \
  mkdir -p ${REPO_DIR} ${OUTPUT_DIR} ; \
  apt-get update ; \
  apt-get install -y git ; \
  cd ${REPO_DIR} ; \
  git clone -b ${branch} --single-branch ${URL} . ; \
  dart pub get; \
  dart run melos bootstrap --scope="noports_core" --scope="sshnoports"; \
  dart pub get -C ${PACKAGE_DIR}; \
  dart compile exe ${PACKAGE_DIR}/bin/sshnp.dart -o ${OUTPUT_DIR}/sshnp ; \
  dart compile exe ${PACKAGE_DIR}/bin/sshnpd.dart -o ${OUTPUT_DIR}/sshnpd ; \
  dart compile exe ${PACKAGE_DIR}/bin/sshrv.dart -o ${OUTPUT_DIR}/sshrv ; \
  dart compile exe ${PACKAGE_DIR}/bin/sshrvd.dart -o ${OUTPUT_DIR}/sshrvd ; \
  dart compile exe ${PACKAGE_DIR}/bin/activate_cli.dart -o ${OUTPUT_DIR}/at_activate ;

# RUNTIME BRANCH
FROM base AS runtime-branch

COPY --chown=${USER}:${USER} --from=build-branch /app/output ${HOMEDIR}/.local/bin

WORKDIR ${HOMEDIR}

USER ${USER}

ENTRYPOINT cp -r /mount/. ${HOMEDIR} && sudo service ssh start && sh ${HOMEDIR}/entrypoint.sh
# END BRANCH

# LOCAL
# BUILD LOCAL
FROM dart:3.1.3@sha256:b42328ca91e961fdec1346e930df42fb027d51cfba04af2a748764bbc867e1f8 AS build-local

ENV REPO_DIR=/app/repo
ENV PACKAGE_DIR=${REPO_DIR}/packages/sshnoports
ENV OUTPUT_DIR=/app/output

RUN mkdir -p ${REPO_DIR} ${OUTPUT_DIR} ;

# context must be the root of the repo
COPY . ${REPO_DIR}

RUN set -eux ; \
  cd ${REPO_DIR}; \
  dart pub get; \
  dart run melos bootstrap --scope="noports_core" --scope="sshnoports"; \
  dart pub get -C ${PACKAGE_DIR}; \
  dart compile exe ${PACKAGE_DIR}/bin/sshnp.dart -o ${OUTPUT_DIR}/sshnp ; \
  dart compile exe ${PACKAGE_DIR}/bin/sshnpd.dart -o ${OUTPUT_DIR}/sshnpd ; \
  dart compile exe ${PACKAGE_DIR}/bin/sshrv.dart -o ${OUTPUT_DIR}/sshrv ; \
  dart compile exe ${PACKAGE_DIR}/bin/sshrvd.dart -o ${OUTPUT_DIR}/sshrvd ; \
  dart compile exe ${PACKAGE_DIR}/bin/activate_cli.dart -o ${OUTPUT_DIR}/at_activate ;

# RUNTIME LOCAL
FROM base AS runtime-local

COPY --chown=${USER}:${USER} --from=build-local /app/output ${HOMEDIR}/.local/bin

WORKDIR ${HOMEDIR}

USER ${USER}

ENTRYPOINT cp -r /mount/. ${HOMEDIR} && sudo service ssh start && sh ${HOMEDIR}/entrypoint.sh
# END LOCAL

# RELEASE
# BUILD RELEASE
FROM debian:stable-20231009-slim@sha256:8cfbea7c925801b678943e59e3ae6fc5b925e8bfe0243f4e724e180edb5aabcd AS build-release

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
  if [ -z ${release} ] || [ "${release}" = 'latest' ]; then \
  LATEST_VERSION=$(curl --silent ${URL} | grep -Po '"tag_name": "\Kv.*?(?=")') ; \
  VERSION=${LATEST_VERSION} ; \
  else \
  VERSION=${release} ; \
  fi ; \
  wget "${URLP}/${VERSION}/sshnp-linux-${ARCH}.tgz" ; \
  tar -xvf sshnp-linux-${ARCH}.tgz ; \
  rm sshnp-linux-${ARCH}.tgz ; \
  cd sshnp ; \
  mv sshnp sshnpd sshrv sshrvd at_activate ${OUTPUT_DIR} ;

# RUNTIME RELEASE
FROM base AS runtime-release

COPY --chown=${USER}:${USER} --from=build-release /app/output ${HOMEDIR}/.local/bin

WORKDIR ${HOMEDIR}

USER ${USER}

ENTRYPOINT cp -r /mount/. ${HOMEDIR} && sudo service ssh start && sh ${HOMEDIR}/entrypoint.sh
# END RELEASE

# SSHNP INSTALLER
# BUILD SSHNP INSTALLER
FROM base AS build-sshnp-installer

USER ${USER}
WORKDIR ${HOMEDIR}

ENV REPO_DIR=/app/repo

# context must be the root of the repo
COPY . ${REPO_DIR}

ARG client_atsign
ARG device_atsign
ARG host_atsign

RUN set -eux; \
  sh ${REPO_DIR}/scripts/install_sshnp \
  -c ${client_atsign} \
  -d ${device_atsign} \
  -h ${host_atsign};

# RUNTIME SSHNP INSTALLER
FROM build-sshnp-installer AS runtime-sshnp-installer

USER ${USER}
WORKDIR ${HOMEDIR}

ENTRYPOINT cp -r /mount/. ${HOMEDIR} && sudo service ssh start && sh ${HOMEDIR}/entrypoint.sh
# END SSHNP INSTALLER

# SSHNPD INSTALLER
# BUILD SSHNPD INSTALLER
FROM base AS build-sshnpd-installer

USER ${USER}
WORKDIR ${HOMEDIR}

ENV REPO_DIR=/app/repo

# context must be the root of the repo
COPY . ${REPO_DIR}

ARG client_atsign
ARG device_atsign
ARG device_name

RUN set -eux ; \
  sudo service cron start; \
  sudo service ssh start; \
  sh ${REPO_DIR}/scripts/install_sshnpd \
  -c ${client_atsign} \
  -d ${device_atsign} \
  -n ${device_name} \
  --args "-s -u -v" ;

# RUNTIME SSHNPD INSTALLER
FROM build-sshnpd-installer AS runtime-sshnpd-installer

USER ${USER}
WORKDIR ${HOMEDIR}

ENTRYPOINT cp -r /mount/. ${HOMEDIR} && sudo service ssh start && sh ${HOMEDIR}/entrypoint.sh
# END SSHNPD INSTALLER

# MANUAL
FROM runtime-branch AS manual-branch

ENTRYPOINT sudo service ssh start && bash

FROM runtime-release AS manual-release

ENTRYPOINT sudo service ssh start && bash

FROM runtime-local AS manual-local

ENTRYPOINT sudo service ssh start && bash

FROM base AS manual-blank

WORKDIR ${HOMEDIR}

USER ${USER}

ENTRYPOINT sudo service ssh start && bash
# END MANUAL