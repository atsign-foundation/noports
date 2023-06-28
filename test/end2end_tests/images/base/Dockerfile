FROM debian:stable-20230612-slim@sha256:b09f68bffcf9c14f3105f262e92321d05abaf48460d1f43f884325bcd4395b95

ENV USER=atsign
ENV HOMEDIR=/${USER}
ENV USER_ID=1024
ENV GROUP_ID=1024

RUN set -eux ; \
    apt-get update ; \
    apt-get install -y openssh-server sudo wget curl openssh-server nano vim iproute2 nmap tmux git dpkg ; \
    groupadd --gid ${GROUP_ID} ${USER} ; \
    useradd --system --shell /bin/bash --home ${HOMEDIR} --uid ${USER_ID} --gid ${GROUP_ID} ${USER} ; \
    usermod -aG sudo ${USER} ; \
    mkdir -p ${HOMEDIR}/.ssh ; \
    touch ${HOMEDIR}/.ssh/authorized_keys ; \
    ssh-keygen -t ed25519 -a 100 -f ${HOMEDIR}/.ssh/id_ed25519 -q -N '' ; \
    chown -R ${USER}:${USER} ${HOMEDIR} ; \
    ex +"%s/^%sudo.*$/%sudo ALL=(ALL:ALL) NOPASSWD:ALL/g" -scwq! /etc/sudoers ; \
    sed -E -i 's|^#?(PasswordAuthentication)\s.*|\1 no|' /etc/ssh/sshd_config ; \
    sed -i 's/#ListenAddress 0.0.0.0/ListenAddress 127.0.0.1/g' /etc/ssh/sshd_config ;
