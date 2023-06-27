FROM dart:3.0.5@sha256:65e5f5d6d72ad2f7b32f402c01b5fe8a426455b1ede1e9f840f95a2a8c14afbd AS buildimage

ENV BUILDDIR=/build
ENV OUTPUTDIR=/output

WORKDIR ${BUILDDIR}

COPY . .

RUN mkdir -p ${OUTPUTDIR} ; \
    dart pub get ; \
    dart compile exe ${BUILDDIR}/bin/sshnp.dart -o ${OUTPUTDIR}/sshnp ; \
    dart compile exe ${BUILDDIR}/bin/sshnpd.dart -o ${OUTPUTDIR}/sshnpd ; \
    dart compile exe ${BUILDDIR}/bin/sshrv.dart -o ${OUTPUTDIR}/sshrv ; \
    dart compile exe ${BUILDDIR}/bin/sshrvd.dart -o ${OUTPUTDIR}/sshrvd ; \
    dart compile exe ${BUILDDIR}/bin/activate_cli.dart -o ${OUTPUTDIR}/at_activate ;

FROM atsigncompany/sshnp_test_base:latest

RUN mkdir -p ${HOMEDIR}/.atsign/keys ${HOMEDIR}/.local/bin

COPY --chown=${USER}:${USER} tools/end2end_tests/keys/*.atKeys ${HOMEDIR}/.atsign/keys
COPY --chown=${USER}:${USER} --from=buildimage /output ${HOMEDIR}/.local/bin

WORKDIR ${HOMEDIR}

USER ${USER}

ENTRYPOINT sudo service ssh start && bash