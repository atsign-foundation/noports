FROM dart:3.0.5@sha256:65e5f5d6d72ad2f7b32f402c01b5fe8a426455b1ede1e9f840f95a2a8c14afbd AS buildimage
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
FROM debian:stable-20230522-slim@sha256:d828cca5497a2519da9c6d42372066895fa28a69f1e8a46a38ce8f750bd2adf0
ENV USER=atsign
ENV HOMEDIR=/${USER}
ENV BINARYDIR=/usr/local/at
ENV USER_ID=1024
ENV GROUP_ID=1024
COPY --from=buildimage /app/.startup.sh ${HOMEDIR}/
RUN \
   set -eux ; \
   apt-get update && apt-get install -y openssh-server sudo iputils-ping iproute2 ncat telnet net-tools nmap iperf3 tmux traceroute vim;\
   addgroup --gid ${GROUP_ID} ${USER} ; \
   sysctl -w net.ipv4.ping_group_range="0 1024" ; \
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
