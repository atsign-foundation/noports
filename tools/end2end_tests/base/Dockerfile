FROM debian:latest

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
    cd ${HOMEDIR}/.ssh ; \
    touch authorized_keys ; \
    chmod 600 ${HOMEDIR}/.ssh ; \
    ssh-keygen -t ed25519 -a 100 -f id_ed25519 -q -N '' ; \
    chown -R ${USER}:${USER} ${HOMEDIR} ; \
    ex +"%s/^%sudo.*$/%sudo ALL=(ALL:ALL) NOPASSWD:ALL/g" -scwq! /etc/sudoers ; \
    sed -E -i 's|^#?(PasswordAuthentication)\s.*|\1 no|' /etc/ssh/sshd_config ; \
    sed -i 's/#ListenAddress 0.0.0.0/ListenAddress 127.0.0.1/g' /etc/ssh/sshd_config ;
