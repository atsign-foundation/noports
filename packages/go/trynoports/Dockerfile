# N.B. this Dockerfile assumes you are running from the root of the repository

FROM dart:3.3.4@sha256:816fee592c641f61ff42461d23cfc3bee301f21e2288cb6818ab961c44c6efc0  AS dart-builder
ENV PACKAGEDIR=packages/dart/sshnoports
ENV ATKEYSDIR=packages/go/trynoports/.atsign/keys
ENV SSHKEYSDIR=packages/go/trynoports/.ssh
ENV OPENSSH=tools/static-openssh
ENV BINARYDIR=/usr/local/at
ENV HOMEDIR=/atsign
ENV WORKDIR=/app
ENV USER_ID=1024
ENV GROUP_ID=1024
SHELL ["/bin/bash", "-c"]
WORKDIR /app
COPY . .
RUN \
  set -eux ; \
  mkdir -p $HOMEDIR/storage ; \
  mkdir -p $HOMEDIR/config ; \
  mkdir -p $HOMEDIR/.ssh ; \
  mkdir -p $HOMEDIR/.sshnp ; \
  mkdir -p $HOMEDIR/.atsign/keys ; \
  mkdir -p /etc/cacert ; \
  mkdir -p ${BINARYDIR} ;
WORKDIR ${WORKDIR}/${PACKAGEDIR}
RUN \
  # build sshnpd
  dart pub get --enforce-lockfile ; \
  dart compile exe bin/sshnpd.dart -o ${BINARYDIR}/sshnpd ; \
  dart compile exe bin/srv.dart -o ${BINARYDIR}/srv ; \
  # create atsign account
  addgroup --gid $GROUP_ID atsign ; \
  useradd --system --uid $USER_ID --gid $GROUP_ID --shell /bin/bash \
  --home $HOMEDIR atsign ; \
  mv ${WORKDIR}/${ATKEYSDIR}/* ${HOMEDIR}/.atsign/keys/ ; \
  mv ${WORKDIR}/${SSHKEYSDIR}/* ${HOMEDIR}/.ssh/ ; \
  chown -R atsign:atsign $HOMEDIR ; \
  # build static openssh binaries
  apt-get -y update && apt-get install -y --no-install-recommends curl gcc make autoconf ;

# WORKDIR ${WORKDIR}/${OPENSSH}
# RUN \
#   ./static-openssh.sh ; \
#   cp build/openssh-portable*/ssh-keygen ${BINARYDIR}/ ; \
#   chmod 755 ${BINARYDIR}/ssh-keygen ; \
#   chmod 755 ${BINARYDIR}/ssh

# TODO  build static version of ip command

# TODO  build static version of nmap command

FROM golang:1.22.2-bookworm as golang-builder
ENV PACKAGEDIR=packages/go/trynoports
ENV BINARYDIR=/usr/local/at
ENV WORKDIR=/app
ENV CGO_ENABLED=0
WORKDIR /app
COPY . .

WORKDIR ${WORKDIR}/${PACKAGEDIR}
RUN \
  mkdir -p ${BINARYDIR} ; \
  go build . ; \
  mv ./trynoports ${BINARYDIR}/trynoports ;

# Second stage of build FROM scratch
FROM scratch
ENV PATH=/usr/local/at
ENV USER=atsign
ENV HOME=/atsign
COPY --from=dart-builder /atsign/ /atsign/
COPY --from=dart-builder /runtime/ /
COPY --from=dart-builder /etc/passwd /etc/passwd
COPY --from=dart-builder /etc/group /etc/group
COPY --from=dart-builder /etc/cacert /etc/cacert
WORKDIR /usr/local/at
# noports daemon + socket connector
COPY --from=dart-builder  /usr/local/at/sshnpd /usr/local/at/
COPY --from=dart-builder  /usr/local/at/srv /usr/local/at/
# COPY --from=dart-builder  /usr/local/at/ssh-keygen /usr/local/at/

COPY --from=golang-builder  /usr/local/at/trynoports /usr/local/at/
USER atsign
ENTRYPOINT ["/usr/local/at/trynoports"]
