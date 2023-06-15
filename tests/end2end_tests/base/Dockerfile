FROM dart:latest AS buildimage

# compiles sshnp, sshrv, sshnpd, sshrvd, and at_activate inside of /app/bin

RUN mkdir -p /app/bin /app/repo

WORKDIR /app

ARG branch=trunk

RUN apt-get update ; \
    apt-get install -y git ; \
    cd repo ; \
    git clone https://github.com/atsign-foundation/sshnoports . ; \
    git checkout ${branch} ; \
    dart pub get ; \
    dart compile exe /app/repo/bin/sshnp.dart -o /app/bin/sshnp ; \
    dart compile exe /app/repo/bin/sshrv.dart -o /app/bin/sshrv ; \
    dart compile exe /app/repo/bin/sshnpd.dart -o /app/bin/sshnpd ; \
    dart compile exe /app/repo/bin/sshrvd.dart -o /app/bin/sshrvd ; \
    dart compile exe /app/repo/bin/activate_cli.dart -o /app/bin/at_activate ; 

FROM debian:latest

ENV USER=atsign
ENV HOMEDIR=/$USER
ENV USER_ID=1024
ENV GROUP_ID=1024

# install necessities
RUN apt-get update ; \
    apt-get install -y sudo wget curl openssh-server nano vim iproute2 nmap tmux git;

# set up user
RUN groupadd --gid ${GROUP_ID} ${USER} ; \
    useradd --system --shell /bin/bash --home ${HOMEDIR} --uid ${USER_ID} --gid ${GROUP_ID} ${USER} ; \
    usermod -aG sudo ${USER} ;

RUN mkdir -p ${HOMEDIR}/.ssh ; \
    touch ${HOMEDIR}/.ssh/authorized_keys ; \
    chown -R ${USER}:${USER} ${HOMEDIR} ;

# disable sudo password, requires vim
RUN ex +"%s/^%sudo.*$/%sudo ALL=(ALL:ALL) NOPASSWD:ALL/g" -scwq! /etc/sudoers ;

# "PasswordAuthentication no" in /etc/ssh/sshd_config
RUN sed -E -i 's|^#?(PasswordAuthentication)\s.*|\1 no|' /etc/ssh/sshd_config

# "ListenAddress 127.0.0.1" in /etc/ssh/sshd_config
RUN sed -i 's/#ListenAddress 0.0.0.0/ListenAddress 127.0.0.1/g' /etc/ssh/sshd_config

# copy binaries from buildimage
RUN mkdir -p ${HOMEDIR}/.local/bin ${HOMEDIR}/repo ;
COPY --from=buildimage --chown=${USER}:${USER} /app/bin/* ${HOMEDIR}/.local/bin

WORKDIR ${HOMEDIR}

# RUN echo '${USER}:123' | sudo chpasswd 
    
USER ${USER}

ENTRYPOINT sudo service ssh start && bash
