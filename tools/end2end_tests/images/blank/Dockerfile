FROM atsigncompany/sshnp_test_base:latest

RUN mkdir -p ${HOMEDIR}/.atsign/keys

COPY --chown=${USER}:${USER} keys/*.atKeys ${HOMEDIR}/.atsign/keys

WORKDIR ${HOMEDIR}

USER ${USER}

ENTRYPOINT sudo service ssh start && bash