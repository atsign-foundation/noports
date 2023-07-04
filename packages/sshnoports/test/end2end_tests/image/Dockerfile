FROM dart:3.0.5@sha256:65e5f5d6d72ad2f7b32f402c01b5fe8a426455b1ede1e9f840f95a2a8c14afbd AS trunk-build

ENV URL=https://github.com/atsign-foundation/sshnoports.git
ENV REPO_DIR=/app/repo
ENV OUTPUT_DIR=/app/output

ARG branch=trunk

RUN apt-get update ; \
    apt-get install -y git ; \
    cd ${REPO_DIR} ; \
    git clone -b ${branch} --single-branch ${URL} . ; \
    cd packages/sshnoports ; \
    dart pub get ; \
    dart compile exe ${REPO_DIR}/packages/sshnoports/bin/sshnp.dart -o ${OUTPUT_DIR}/sshnp ; \
    dart compile exe ${REPO_DIR}/packages/sshnoports/bin/sshnpd.dart -o ${OUTPUT_DIR}/sshnpd ; \
    dart compile exe ${REPO_DIR}/packages/sshnoports/bin/sshrv.dart -o ${OUTPUT_DIR}/sshrv ;
    # dart compile exe ${BUILDDIR}/repo/bin/sshrvd.dart -o ${BUILDDIR}/bin/sshrvd ; \
    # dart compile exe ${BUILDDIR}/repo/bin/activate_cli.dart -o ${BUILDDIR}/bin/at_activate ;

FROM dart:3.0.5@sha256:65e5f5d6d72ad2f7b32f402c01b5fe8a426455b1ede1e9f840f95a2a8c14afbd AS local-build

ENV REPO_DIR=/app/repo
ENV OUTPUT_DIR=/app/output

RUN mkdir -p ${REPO_DIR} ${OUTPUT_DIR} ;

COPY ../../../../ ${REPO_DIR}

RUN cd ${REPO_DIR} ; \
    dart pub get ; \
    dart compile exe ${REPO_DIR}/bin/sshnp.dart -o ${OUTPUTDIR}/sshnp ; \
    dart compile exe ${REPO_DIR}/bin/sshnpd.dart -o ${OUTPUTDIR}/sshnpd ; \
    dart compile exe ${REPO_DIR}/bin/sshrv.dart -o ${OUTPUTDIR}/sshrv ;
    # dart compile exe ${REPO_DIR}/bin/sshrvd.dart -o ${OUTPUTDIR}/sshrvd ; \
    # dart compile exe ${REPO_DIR}/bin/activate_cli.dart -o ${OUTPUTDIR}/at_activate ;

FROM debian:stable-20230612-slim@sha256:b09f68bffcf9c14f3105f262e92321d05abaf48460d1f43f884325bcd4395b95 AS release-build

ARG release="3.3.0"

RUN mkdir -p ${HOMEDIR}/.atsign/keys ${HOMEDIR}/.local/bin ${HOMEDIR}/tmp/build ; \
    cd ${HOMEDIR}/tmp/build ; \
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
    URL="https://api.github.com/repos/atsign-foundation/sshnoports/releases/latest"; \
    URLP="https://github.com/atsign-foundation/sshnoports/releases/download"; \
    if [ -z "${release}" ]; \
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
    mv sshnp sshnpd sshrv sshrvd at_activate ${HOMEDIR}/.local/bin ;

FROM debian:stable-20230612-slim@sha256:b09f68bffcf9c14f3105f262e92321d05abaf48460d1f43f884325bcd4395b95 AS base

ENV USER=atsign
ENV HOMEDIR=/${USER}
ENV USER_ID=1024
ENV GROUP_ID=1024

RUN set -eux ; \
    apt-get update ; \
    apt-get install -y openssh-server sudo wget curl openssh-server nano vim iproute2 nmap tmux git dpkg ; \
    groupadd --gid ${GROUP_ID} ${USER} ; \
    useradd --system --shell /bin/bash --home ${HOMEDIR} --uid ${USER_ID} --gid ${GROUP_ID} ${USER} ; \
    usermod -aG sudo ${USER} ; \
    mkdir -p ${HOMEDIR}/.ssh ; \
    touch ${HOMEDIR}/.ssh/authorized_keys ; \
    ssh-keygen -t ed25519 -a 100 -f ${HOMEDIR}/.ssh/id_ed25519 -q -N '' ; \
    chown -R ${USER}:${USER} ${HOMEDIR} ; \
    ex +"%s/^%sudo.*$/%sudo ALL=(ALL:ALL) NOPASSWD:ALL/g" -scwq! /etc/sudoers ; \
    sed -E -i 's|^#?(PasswordAuthentication)\s.*|\1 no|' /etc/ssh/sshd_config ; \
    sed -i 's/#ListenAddress 0.0.0.0/ListenAddress 127.0.0.1/g' /etc/ssh/sshd_config ;


# depends on the base image - `sudo docker build -t atsigncompany/sshnp-e2e-base -f ./images/base/Dockerfile ./images/base`
FROM base

RUN mkdir -p ${HOMEDIR}/.atsign/keys ${HOMEDIR}/.local/bin ;

COPY --chown=${USER}:${USER} --from=trunk-build /app/output ${HOMEDIR}/.local/bin
COPY --chown=${USER}:${USER} --from=release-build /app/output ${HOMEDIR}/.local/bin
COPY --chown=${USER}:${USER} --from=local-build /app/output ${HOMEDIR}/.local/bin

WORKDIR ${HOMEDIR}

USER ${USER}

ENTRYPOINT sudo service ssh start && sh ${HOMEDIR}/entrypoint.sh
