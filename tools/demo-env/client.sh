#!/bin/sh

__norm_atsign() {
  ATSIGN="$1"
  FIRST="${ATSIGN:0:1}"

  if ! [ "$FIRST" = "@" ]; then
    ATSIGN="@$ATSIGN"
  fi

  case "$ATSIGN" in
    @emoji) printf "$ATSIGN🦄🛠";;
    @srie|@sachin) printf "$ATSIGN" ;;
    *) printf "$ATSIGN🛠" ;;
  esac
}

__usage() {
  echo "noports <client> <device> <relay> <service>"
  echo ""
  echo "<client>, <device>, and <relay> should all be specified without any emojis, they will be added for you"
  echo "e.g. '@colin' or 'colin' both yield '@colin🛠'"
  echo ""
  echo "<service> can be one of 'ssh', 'http', 'vnc', 'rdp'"
  echo
}

noports() {
  if [ "$#" -ne 4 ]; then
    __usage
    return
  fi

  FROM=$(__norm_atsign "$1")
  TO=$(__norm_atsign "$2")
  RELAY=$(__norm_atsign "$3")
  SERVICE="$4"

  case $SERVICE in
    ssh)
      echo "sshnp --root-domain vip.ve.atsign.zone -f $FROM -t $TO -r $RELAY -u atsign -s -i $HOME/.ssh/id_ed25519"
      ;;
    http)
      echo "npt --root-domain vip.ve.atsign.zone -f $FROM -t $TO -r $RELAY -d default -p 80 -l 8080 -K"
      echo "# Then connect to: http://localhost:8080" 1>&2
      ;;
    vnc)
      echo "npt --root-domain vip.ve.atsign.zone -f $FROM -t $TO -r $RELAY -d default -h host.docker.internal -p 5900 -l 59000 -K"
      echo "# Then connect to: vnc://localhost:59000" 1>&2
      ;;
    rdp)
      echo "npt --root-domain vip.ve.atsign.zone -f $FROM -t $TO -r $RELAY -d default -h host.docker.internal -p 3389 -l 33899 -K"
      echo "# Then connect to: rdp://localhost:33899" 1>&2
      ;;
    *)
      __usage
      return
      ;;
  esac
}


