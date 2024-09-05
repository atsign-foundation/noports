FROM alpine:3.20
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

ARG BASE_URL=https://github.com/atsign-foundation/noports/releases/download
ARG RELEASE=v5.6.1
ARG ENTRYPOINT=entrypoint.sh

WORKDIR /home/atsign
ENV HOME=/home/atsign
ENV USER=atsign

# setup base
COPY ./$ENTRYPOINT /home/atsign/entrypoint.sh

# hadolint ignore=DL3018
RUN \
  apk add --no-cache sudo openssh nginx libc6-compat bind-tools ca-certificates; \
  adduser -D -H atsign; \
  # activate atsign account
  echo "atsign:foobar" | chpasswd -e; \
  # add atsign to sudoers
  echo '%wheel ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/wheel; \
  adduser atsign wheel; \
  chmod u+x /home/atsign/entrypoint.sh;

# setup sshd
COPY ./sshd.sh /home/atsign/sshd.sh
RUN \
  mkdir -p /home/atsign/.ssh; \
  touch /home/atsign/.ssh/authorized_keys; \
  chmod u+x /home/atsign/sshd.sh; \
  { echo; echo "# Injected config"; \
  echo "ListenAddress localhost"; \
  echo "PasswordAuthentication no"; \
  } >> /etc/ssh/sshd_config;

# setup nginx
RUN \
  mkdir /www; \
  chown -R atsign:atsign /var/lib/nginx; \
  chown -R atsign:atsign /www;

COPY nginx.conf /etc/nginx/nginx.conf
COPY index.html /www/index.html

RUN \
  mkdir /www/files; \
  echo "world" > /www/files/hello; \
  echo "42" > /www/files/the_meaning_of_life;

# Final setup as atsign user
RUN chown -R atsign:atsign /home/atsign;
USER atsign

RUN set -eux; \
  case $(uname -m) in \
  aarch64) ARCH="arm64";; \
  *) ARCH="x64";; \
  esac; \
  wget -q -O /home/atsign/sshnp.tgz "${BASE_URL}/${RELEASE}/sshnp-linux-${ARCH}.tgz"; \
  tar -xf /home/atsign/sshnp.tgz;

RUN cp /home/atsign/sshnp/srv /home/atsign/srv; \
  cp /home/atsign/sshnp/sshnpd /home/atsign/sshnpd; \
  mkdir -p /home/atsign/.atsign/keys;

ENTRYPOINT [ "/home/atsign/entrypoint.sh" ]
