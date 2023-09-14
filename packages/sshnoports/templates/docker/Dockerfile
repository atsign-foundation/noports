FROM dart:3.1.2@sha256:a57751bdedde962da08789236b12fd3793c10d43a473ef3e73c894d61740fb2c AS buildimage
ENV BINARYDIR=/usr/local/at
SHELL ["/bin/bash", "-c"]
WORKDIR /app
COPY . .
RUN \
  set -eux ; \
  mkdir -p ${BINARYDIR} ; \
  dart pub get ; \
  dart pub update ; \
  dart compile exe bin/sshnpd.dart -o ${BINARYDIR}/sshnpd ; \
  dart compile exe bin/sshrv.dart -o ${BINARYDIR}/sshrv

# Second stage of build FROM debian-slim
FROM debian:stable-20230904-slim@sha256:0941f9e9cc96c4106845a381fb6fca98393f5f659f3eba6a64e9f79219165cfc
ENV USER=atsign
ENV HOMEDIR=/${USER}
ENV BINARYDIR=/usr/local/at
ENV USER_ID=1024
ENV GROUP_ID=1024

COPY --from=buildimage /app/templates/docker/.startup.sh ${HOMEDIR}/
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
