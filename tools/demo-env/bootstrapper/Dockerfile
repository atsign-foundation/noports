FROM alpine:3.20
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
RUN apk add --no-cache git=2.45.2-r0

WORKDIR /home/atsign

ADD "https://api.github.com/repos/atsign-foundation/at_demos/commits?per_page=1" latest_commit

RUN git clone https://github.com/atsign-foundation/at_demos.git /home/atsign/at_demos; \
  mkdir -p /home/atsign/mount; \
  cp /home/atsign/at_demos/packages/at_demo_data/lib/assets/atkeys/* /home/atsign/mount/;

RUN files="$(ls /home/atsign/mount)"; \
  for f in ${files}; do \
  mv /home/atsign/mount/"$f" /home/atsign/mount/"$(echo "$f" | sed -e 's/.atKeys/_key.atKeys/g')"; \
  done

ENTRYPOINT [ "/bin/true" ]
