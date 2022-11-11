FROM dart:2.18.4 AS buildimage
ENV HOMEDIR=/atsign
ENV BINARYDIR=/usr/local/at
ENV USER_ID=1024
ENV GROUP_ID=1024
WORKDIR /app
COPY . .
RUN \
  mkdir -p $HOMEDIR/.atsign/keys ; \
  mkdir -p $HOMEDIR/.ssh ; \
  touch $HOMEDIR/.ssh/authorized_keys ; \
  chmod 600 $HOMEDIR/.ssh/authorized_keys ; \
  mkdir -p $BINARYDIR ; \
  dart pub get ; \
  dart pub update ; \
  dart compile exe bin/sshnpd.dart -o $BINARYDIR/sshnpd ; \
  addgroup --gid $GROUP_ID atsign ; \
  useradd --system --uid $USER_ID --gid $GROUP_ID --shell /bin/bash  --home $HOMEDIR atsign ; \
  chown -R atsign:atsign $HOMEDIR ; 

# Second stage of build FROM scratch
FROM debian
COPY --from=buildimage /etc/passwd /etc/passwd
COPY --from=buildimage /etc/group /etc/group
COPY --from=buildimage --chown=atsign:atsign /atsign /atsign/
COPY --from=buildimage --chown=atsign:atsign /app/startup.sh /atsign/
COPY --from=buildimage --chown=atsign:atsign /usr/local/at/sshnpd /usr/local/at/
RUN apt-get update && apt-get install -y openssh-server sudo iputils-ping iproute2 tmux
RUN usermod -aG sudo atsign
RUN sysctl -w net.ipv4.ping_group_range="0 1024"
RUN mkdir /run/sshd
RUN chmod 755 /atsign/startup.sh
WORKDIR /atsign
# USER atsign
ENTRYPOINT ["/atsign/startup.sh"]
