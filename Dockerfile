FROM dart:2.18.6@sha256:33caaa23adc28949959517733f989e86f077ea6dee825d543685df1fcf5d57f1 AS buildimage
ENV BINARYDIR=/usr/local/at
WORKDIR /app
COPY . .
RUN \
  mkdir -p $BINARYDIR ; \
  dart pub get ; \
  dart pub update ; \
  dart compile exe bin/sshnpd.dart -o $BINARYDIR/sshnpd

# Second stage of build FROM debian-slim
FROM debian:stable-20230109-slim@sha256:439abf32c7a53d22e3b81a64023538fd5cf490c5837a93d4589a83617bb00d5d
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
