RED='\033[0;31m'
NC='\033[0m'

if [ -z "$testsToRun" ] ; then
  echo -e "    ${RED}check_env: testsToRun is not set${NC}" && exit 1
fi

if [ -z "$daemonVersions" ] ; then
  echo -e "    ${RED}check_env: daemonVersions is not set${NC}" && exit 1
fi

if [ -z "$clientVersions" ] ; then
  echo -e "    ${RED}check_env: clientVersions is not set${NC}" && exit 1
fi

if [ -z "$clientAtSign" ] ; then
  echo -e "    ${RED}check_env: clientAtSign is not set${NC}" && exit 1
fi

if [ -z "$daemonAtSign" ] ; then
  echo -e "    ${RED}check_env: daemonAtSign is not set${NC}" && exit 1
fi

if [ -z "$srvAtSign" ] ; then
  echo -e "    ${RED}check_env: srvAtSign is not set${NC}" && exit 1
fi

if [ -z "$commitId" ] ; then
  echo -e "    ${RED}check_env: commitId is not set${NC}" && exit 1
fi

if [ -z "$atDirectoryHost" ] ; then
  echo -e "    ${RED}check_env: atDirectoryHost is not set${NC}" && exit 1
fi

if [ -z "$atDirectoryPort" ] ; then
  echo -e "    ${RED}check_env: atDirectoryPort is not set${NC}" && exit 1
fi

if [ -z "$repoRootDir" ] ; then
  echo -e "    ${RED}check_env: repoRootDir is not set${NC}" && exit 1
fi

if [ -z "$testRootDir" ] ; then
  echo -e "    ${RED}check_env: testRootDir is not set${NC}" && exit 1
fi

if [ -z "$testRuntimeDir" ] ; then
  echo -e "    ${RED}check_env: testRuntimeDir is not set${NC}" && exit 1
fi
