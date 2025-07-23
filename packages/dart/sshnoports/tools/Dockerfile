# Dockerfile
# Build image for a containerized instance of sshnpd

FROM dart:3.8.2@sha256:660a0751a021250d588af61322ab2cce9edef6002960638a4b0c09ede7427b99 AS buildimage
ENV PACKAGEDIR=packages/dart/sshnoports
ENV BINARYDIR=/usr/local/at
SHELL ["/bin/bash", "-c"]
WORKDIR /app
COPY . .
RUN \
  set -eux ; \
  mkdir -p ${BINARYDIR} ; \
  cd ${PACKAGEDIR}; \
  dart pub get --enforce-lockfile; \
  dart run build_runner build --delete-conflicting-outputs ; \
  dart compile exe bin/sshnpd.dart -o ${BINARYDIR}/sshnpd ; \
  dart compile exe bin/srv.dart -o ${BINARYDIR}/srv

# Second stage of build FROM debian-slim
FROM debian:stable-20250721-slim@sha256:377ddc2a20fe8632a49b69dcfff10fccbd5b4f0b8c2d593420a6a5e03070dfa1
ENV USER=atsign
ENV HOMEDIR=/${USER}
ENV BINARYDIR=/usr/local/at
ENV USER_ID=1024
ENV GROUP_ID=1024

COPY --from=buildimage /app/packages/dart/sshnoports/bundles/core/docker/.startup.sh ${HOMEDIR}/
RUN \
  set -eux ; \
  apt-get update ; \
  apt-get install -y openssh-server sudo iputils-ping iproute2 ncat telnet net-tools nmap iperf3 traceroute vim ; \
  addgroup --gid ${GROUP_ID} ${USER} ; \
  useradd --system --uid ${USER_ID} --gid ${GROUP_ID} --shell /bin/bash --home ${HOMEDIR} ${USER} ; \
  mkdir -p ${HOMEDIR}/.atsign/keys ; \
  mkdir -p ${HOMEDIR}/.ssh ; \
  touch ${HOMEDIR}/.ssh/authorized_keys ; \
  chown -R ${USER}:${USER} ${HOMEDIR} ; \
  chmod 600 ${HOMEDIR}/.ssh/authorized_keys ; \
  usermod -aG sudo ${USER} ; \
  mkdir /run/sshd ; \
  chmod 755 /${USER}/.startup.sh

COPY --from=buildimage --chown=${USER}:${USER} /usr/local/at/sshnpd /usr/local/at/
COPY --from=buildimage --chown=${USER}:${USER} /usr/local/at/srv /usr/local/at/
WORKDIR ${HOMEDIR}
ENTRYPOINT ["/atsign/.startup.sh"]
