FROM dart:3.1.3@sha256:b42328ca91e961fdec1346e930df42fb027d51cfba04af2a748764bbc867e1f8 AS buildimage
ENV PACKAGEDIR=packages/sshnoports
ENV BINARYDIR=/usr/local/at
SHELL ["/bin/bash", "-c"]
WORKDIR /app
COPY . .
RUN \
  set -eux ; \
  mkdir -p ${BINARYDIR} ; \
  cd ${PACKAGEDIR}; \
  dart pub get ; \
  dart run build_runner build --delete-conflicting-outputs ; \
  dart compile exe bin/sshnpd.dart -o ${BINARYDIR}/sshnpd ; \
  dart compile exe bin/sshrv.dart -o ${BINARYDIR}/sshrv

# Second stage of build FROM debian-slim
FROM debian:stable-20231009-slim@sha256:8cfbea7c925801b678943e59e3ae6fc5b925e8bfe0243f4e724e180edb5aabcd
ENV USER=atsign
ENV HOMEDIR=/${USER}
ENV BINARYDIR=/usr/local/at
ENV USER_ID=1024
ENV GROUP_ID=1024

COPY --from=buildimage /app/packages/sshnoports/templates/docker/.startup.sh ${HOMEDIR}/
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
COPY --from=buildimage --chown=${USER}:${USER} /usr/local/at/sshrv /usr/local/at/
WORKDIR ${HOMEDIR}
ENTRYPOINT ["/atsign/.startup.sh"]
