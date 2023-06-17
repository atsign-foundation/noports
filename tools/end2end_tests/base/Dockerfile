FROM debian:latest

ENV USER=atsign
ENV HOMEDIR=/$USER
ENV USER_ID=1024
ENV GROUP_ID=1024

# install necessities
RUN apt-get update ; \
    apt-get install -y sudo wget curl openssh-server nano vim iproute2 nmap tmux git dpkg ;

# set up user
RUN groupadd --gid ${GROUP_ID} ${USER} ; \
    useradd --system --shell /bin/bash --home ${HOMEDIR} --uid ${USER_ID} --gid ${GROUP_ID} ${USER} ; \
    usermod -aG sudo ${USER} ;

# set up authorized_keys
RUN mkdir -p ${HOMEDIR}/.ssh ; \
    touch ${HOMEDIR}/.ssh/authorized_keys ; \
    chown -R ${USER}:${USER} ${HOMEDIR} ;

# disable sudo password, requires vim
RUN ex +"%s/^%sudo.*$/%sudo ALL=(ALL:ALL) NOPASSWD:ALL/g" -scwq! /etc/sudoers ;

# "PasswordAuthentication no" in /etc/ssh/sshd_config
RUN sed -E -i 's|^#?(PasswordAuthentication)\s.*|\1 no|' /etc/ssh/sshd_config

# "ListenAddress 127.0.0.1" in /etc/ssh/sshd_config
RUN sed -i 's/#ListenAddress 0.0.0.0/ListenAddress 127.0.0.1/g' /etc/ssh/sshd_config
