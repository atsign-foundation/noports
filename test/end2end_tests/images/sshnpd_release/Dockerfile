FROM end2end_tests-base:latest

ARG release="3.3.0"

RUN echo "release: ${release}"

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

COPY --chown=${USER}:${USER} ../keys ${HOMEDIR}/.atsign/keys
COPY --chown=${USER}:${USER} entrypoint.sh ${HOMEDIR}/entrypoint.sh

WORKDIR ${HOMEDIR}

USER ${USER}

ENTRYPOINT sudo service ssh start && sh ${HOMEDIR}/entrypoint.sh
