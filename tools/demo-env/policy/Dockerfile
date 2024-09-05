FROM alpine:3.20
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

ARG BASE_URL=https://github.com/atsign-foundation/noports/releases/download
ARG RELEASE=v5.7.0-alpha-2
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


# TODO: temporary solution, switch to the wget download below later
ADD ./sshnp-linux-arm64.tar /home/atsign/
RUN mv /home/atsign/sshnp/web/admin/dist/* /home/atsign/sshnp/web/admin/; \
  chown -R atsign /home/atsign
# END of temporary solution

USER atsign
# RUN case $(uname -m) in \
#   aarch64) ARCH="arm64";; \
#   *) ARCH="x64";; \
#   esac; \
# wget -q -O /home/atsign/sshnp.tgz "$BASE_URL/$RELEASE/sshnp-linux-$ARCH.tgz"; \
# tar -xf /home/atsign/sshnp.tgz;

RUN \
  cp -R /home/atsign/sshnp/web /home/atsign/web; \
  cp /home/atsign/sshnp/admin_api /home/atsign/admin_api; \
  cp /home/atsign/sshnp/npp /home/atsign/npp; \
  mkdir -p /home/atsign/.atsign/keys;

ENTRYPOINT [ "/home/atsign/entrypoint.sh" ]

