FROM dart:3.0.2@sha256:8c414ce9086ef9d370d978fec1e0b3b7f73c0af8c819961c005a8a7ea4b01309 AS buildimage
ENV BINARYDIR=/usr/local/at
WORKDIR /app
COPY . .
RUN \
  mkdir -p $BINARYDIR ; \
  dart pub get ; \
  dart pub update ; \
  dart compile exe bin/sshnpd.dart -o $BINARYDIR/sshnpd

# Second stage of build FROM debian-slim
FROM debian:stable-20230522-slim@sha256:d828cca5497a2519da9c6d42372066895fa28a69f1e8a46a38ce8f750bd2adf0
ENV HOMEDIR=/atsign
ENV BINARYDIR=/usr/local/at
ENV USER_ID=1024
ENV GROUP_ID=1024
COPY --from=buildimage  /app/.startup.sh /atsign/
RUN apt-get update && apt-get install -y openssh-server sudo iputils-ping iproute2 ncat telnet net-tools nmap iperf3 tmux traceroute vim;\
   addgroup --gid $GROUP_ID atsign ; \
   sysctl -w net.ipv4.ping_group_range="0 1024" ; \
   useradd --system --uid $USER_ID --gid $GROUP_ID --shell /bin/bash  --home $HOMEDIR atsign ; \
   mkdir -p $HOMEDIR/.atsign/keys ; \
   mkdir -p $HOMEDIR/.ssh ; \
   touch $HOMEDIR/.ssh/authorized_keys ; \
   chown -R atsign:atsign $HOMEDIR ; \
   chmod 600 $HOMEDIR/.ssh/authorized_keys ; \
   usermod -aG sudo atsign ; \
   mkdir /run/sshd ; \
   chmod 755 /atsign/.startup.sh
COPY --from=buildimage --chown=atsign:atsign /usr/local/at/sshnpd /usr/local/at/
WORKDIR /atsign
# USER atsign 
ENTRYPOINT ["/atsign/.startup.sh"]
