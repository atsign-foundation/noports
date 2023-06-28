FROM dart:3.0.5@sha256:65e5f5d6d72ad2f7b32f402c01b5fe8a426455b1ede1e9f840f95a2a8c14afbd AS buildimage

ENV BUILDDIR=/build
ENV OUTPUTDIR=/output

WORKDIR ${BUILDDIR}

COPY . .

RUN ls -la

RUN mkdir -p ${OUTPUTDIR} ${BUILDDIR} ; \
    dart pub get ; \
    dart compile exe ${BUILDDIR}/bin/sshnp.dart -o ${OUTPUTDIR}/sshnp ; \
    dart compile exe ${BUILDDIR}/bin/sshnpd.dart -o ${OUTPUTDIR}/sshnpd ; \
    dart compile exe ${BUILDDIR}/bin/sshrv.dart -o ${OUTPUTDIR}/sshrv ; \
    dart compile exe ${BUILDDIR}/bin/sshrvd.dart -o ${OUTPUTDIR}/sshrvd ; \
    dart compile exe ${BUILDDIR}/bin/activate_cli.dart -o ${OUTPUTDIR}/at_activate ;

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
    ssh-keygen -t ed25519 -a 100 -f id_ed25519 -q -N '' ; \
    chown -R ${USER}:${USER} ${HOMEDIR} ; \
    ex +"%s/^%sudo.*$/%sudo ALL=(ALL:ALL) NOPASSWD:ALL/g" -scwq! /etc/sudoers ; \
    sed -E -i 's|^#?(PasswordAuthentication)\s.*|\1 no|' /etc/ssh/sshd_config ; \
    sed -i 's/#ListenAddress 0.0.0.0/ListenAddress 127.0.0.1/g' /etc/ssh/sshd_config ; \
    mkdir -p ${HOMEDIR}/.atsign/keys ${HOMEDIR}/.local/bin ; \
    touch ${HOMEDIR}/entrypoint.sh ; \
    chown -R ${USER}:${USER} ${HOMEDIR} ;

COPY --from=buildimage --chown=${USER}:${USER} /output/* ${HOMEDIR}/.local/bin
COPY --chown=${USER}:${USER} entrypoint.sh ${HOMEDIR}/entrypoint.sh
COPY --chown=${USER}:${USER} keys/*.atKeys ${HOMEDIR}/.atsign/keys/

WORKDIR ${HOMEDIR}

USER ${USER}

ENTRYPOINT sudo service ssh start && bash -c /atsign/entrypoint.sh
