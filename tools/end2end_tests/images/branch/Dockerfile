FROM dart:latest AS buildimage

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
    dart compile exe ${BUILDDIR}/repo/bin/sshrv.dart -o ${BUILDDIR}/bin/sshrv ; \
    dart compile exe ${BUILDDIR}/repo/bin/sshrvd.dart -o ${BUILDDIR}/bin/sshrvd ; \
    dart compile exe ${BUILDDIR}/repo/bin/activate_cli.dart -o ${BUILDDIR}/bin/at_activate ;

FROM atsigncompany/sshnp_test_base:latest

RUN mkdir -p ${HOMEDIR}/.atsign/keys ${HOMEDIR}/.local/bin

COPY --chown=${USER}:${USER} keys/*.atKeys ${HOMEDIR}/.atsign/keys
COPY --chown=${USER}:${USER} --from=buildimage /build/bin ${HOMEDIR}/.local/bin

WORKDIR ${HOMEDIR}

USER ${USER}

ENTRYPOINT sudo service ssh start && bash
