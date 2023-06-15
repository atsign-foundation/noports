FROM atsigncompany/sshnp_test_base:latest

RUN mkdir -p ${HOMEDIR}/.atsign/keys ${HOMEDIR}/.ssh

COPY --chown=${USER}:${USER} keys/*.atKeys ${HOMEDIR}/.atsign/keys

CMD sudo service ssh start