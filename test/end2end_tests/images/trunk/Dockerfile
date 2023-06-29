FROM dart:3.0.5@sha256:65e5f5d6d72ad2f7b32f402c01b5fe8a426455b1ede1e9f840f95a2a8c14afbd AS buildimage

ENV URL=https://github.com/atsign-foundation/sshnoports.git
ENV BUILDDIR=/build

ARG branch=trunk

RUN mkdir -p ${BUILDDIR}/bin ${BUILDDIR}/repo ; \
    apt-get update ; \
    apt-get install -y git ;

WORKDIR ${BUILDDIR}/repo

RUN git clone -b ${branch} --single-branch ${URL} . ; \
    dart pub get ; \
    dart compile exe ${BUILDDIR}/repo/bin/sshnp.dart -o ${BUILDDIR}/bin/sshnp ; \
    dart compile exe ${BUILDDIR}/repo/bin/sshnpd.dart -o ${BUILDDIR}/bin/sshnpd ; \
    dart compile exe ${BUILDDIR}/repo/bin/sshrv.dart -o ${BUILDDIR}/bin/sshrv ;
    # dart compile exe ${BUILDDIR}/repo/bin/sshrvd.dart -o ${BUILDDIR}/bin/sshrvd ; \
    # dart compile exe ${BUILDDIR}/repo/bin/activate_cli.dart -o ${BUILDDIR}/bin/at_activate ;

FROM atsigncompany/sshnp-e2e-base:latest

RUN mkdir -p ${HOMEDIR}/.atsign/keys ${HOMEDIR}/.local/bin ; \
    touch results.txt ; \
    chown -R ${USER}:${USER} ${HOMEDIR} ;

COPY --chown=${USER}:${USER} --from=buildimage /build/bin ${HOMEDIR}/.local/bin

COPY --chown=${USER}:${USER} keys/*.atKeys ${HOMEDIR}/.atsign/keys
COPY --chown=${USER}:${USER} entrypoint.sh ${HOMEDIR}/entrypoint.sh

WORKDIR ${HOMEDIR}

USER ${USER}

ENTRYPOINT sudo service ssh start && sh ${HOMEDIR}/entrypoint.sh
