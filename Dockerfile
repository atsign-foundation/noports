FROM dart:2.19.6@sha256:f9c0356d72713aa326d7658d79b5eb8595b55b4fb882282ab3f312db086d1ed4 AS buildimage
ENV BINARYDIR=/usr/local/at
WORKDIR /app
COPY . .
RUN \
  mkdir -p $BINARYDIR ; \
  dart pub get ; \
  dart pub update ; \
  dart compile exe bin/sshnpd.dart -o $BINARYDIR/sshnpd

# Second stage of build FROM debian-slim
FROM alpine:3.17.3@sha256:124c7d2707904eea7431fffe91522a01e5a861a624ee31d03372cc1d138a3126
ENV HOMEDIR=/atsign
ENV BINARYDIR=/usr/local/at
ENV USER_ID=1024
ENV GROUP_ID=1024
COPY --from=buildimage  /app/.startup.sh /atsign/
COPY --from=buildimage /runtime  /
COPY --from=buildimage --chown=atsign:atsign /usr/local/at/sshnpd /usr/local/at/
RUN apk add --no-cache dhclient openssh bash sudo file;\
   echo "sshnpd" > /etc/hostname ; \
  #  rc-update add sshd ; \
  #  service sshd start ; \
  # addgroup --gid $GROUP_ID atsign ; \
   addgroup -g $GROUP_ID atsign ; \
   sysctl -w net.ipv4.ping_group_range="0 1024" ; \
   #useradd --system --uid $USER_ID --gid $GROUP_ID --shell /bin/bash  --home $HOMEDIR atsign ; \
   adduser -S -h $HOMEDIR -s /bin/bash -G atsign -u $USER_ID atsign ; \
   sed -i s/atsign:!/"atsign:*"/g /etc/shadow ; \
   mkdir -p $HOMEDIR/.atsign/keys ; \
   mkdir -p $HOMEDIR/.ssh ; \
   touch $HOMEDIR/.ssh/authorized_keys ; \
   chown -R atsign:atsign $HOMEDIR ; \
   chmod 600 $HOMEDIR/.ssh/authorized_keys ; \
   usermod -aG sudo atsign ; \
   mkdir /run/sshd ; \
   chmod 755 /atsign/.startup.sh
WORKDIR /atsign
# USER atsign 
ENTRYPOINT ["/atsign/.startup.sh"]
