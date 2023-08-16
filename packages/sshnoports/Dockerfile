FROM dart:3.0.7@sha256:3e69d201d73960f8a7e6fb0ee7467ade1495659676a7c09353a39fdb77852b97 AS buildimage
ENV BINARYDIR=/usr/local/at
SHELL ["/bin/bash", "-c"]
WORKDIR /app
COPY . .
RUN \
  set -eux ; \
  mkdir -p ${BINARYDIR} ; \
  dart pub get ; \
  dart pub update ; \
  dart compile exe bin/sshnpd.dart -o ${BINARYDIR}/sshnpd

# Second stage of build FROM debian-slim
FROM debian:stable-20230814-slim@sha256:6fe30b9cb71d604a872557be086c74f95451fecd939d72afe3cffca3d9e60607
ENV USER=atsign
ENV HOMEDIR=/${USER}
ENV BINARYDIR=/usr/local/at
ENV USER_ID=1024
ENV GROUP_ID=1024

COPY --from=buildimage /app/.startup.sh ${HOMEDIR}/
RUN \
   set -eux ; \
   apt-get update && apt-get install -y openssh-server sudo iputils-ping iproute2 ncat telnet net-tools nmap iperf3 tmux traceroute vim ; \
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
WORKDIR ${HOMEDIR}
# USER atsign 
ENTRYPOINT ["/atsign/.startup.sh"]
