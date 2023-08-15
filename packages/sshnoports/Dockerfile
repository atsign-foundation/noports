FROM dart:3.0.7@sha256:faf300f790cadb2e34182dd75c5f14642e21c625396055a16aa967170dfb71d7 AS buildimage
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
FROM debian:stable-20230725-slim@sha256:c9e860b7a6d51a5f90f4fcb645d789c078f7b9d2cc6ebfd48792e0fea5739c04
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
