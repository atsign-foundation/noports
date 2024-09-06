FROM alpine:3.20
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

ARG BASE_URL=https://github.com/atsign-foundation/noports/releases/download
ARG RELEASE=v5.7.0-alpha-5
ARG ENTRYPOINT=entrypoint.sh

WORKDIR /home/atsign
ENV HOME=/home/atsign
ENV USER=atsign

COPY ./$ENTRYPOINT /home/atsign/entrypoint.sh

# hadolint ignore=DL3018
RUN apk add --no-cache libc6-compat bind-tools ca-certificates; \
  adduser -D -H atsign; \
  # activate atsign account
  echo "atsign:*" | chpasswd -e; \
  chown -R atsign /home/atsign; \
  chmod u+x /home/atsign/entrypoint.sh

USER atsign
RUN case $(uname -m) in \
  aarch64) ARCH="arm64";; \
  *) ARCH="x64";; \
  esac; \
  wget -q -O /home/atsign/sshnp.tgz "$BASE_URL/$RELEASE/sshnp-linux-$ARCH.tgz"; \
  tar -xf /home/atsign/sshnp.tgz;

RUN \
  cp -R /home/atsign/sshnp/web /home/atsign/web; \
  cp /home/atsign/sshnp/np_admin /home/atsign/np_admin; \
  cp /home/atsign/sshnp/npp_atserver /home/atsign/npp_atserver; \
  mkdir -p /home/atsign/.atsign/keys;

ENTRYPOINT [ "/home/atsign/entrypoint.sh" ]

