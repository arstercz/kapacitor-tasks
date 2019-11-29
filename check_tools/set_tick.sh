#!/bin/bash

[[ "$DEBUG" ]] && set -x

usage() {
  echo "usage:"
  echo " -d: whether define kapacitor task or not"
  echo " -e: enable kapacitor task"
  exit 0;
}

while getopts "de" o; do
  case "${o}" in
    d)
      DEFINE=1  ;;
    e)
      ENABLE=1  ;;
    *)
      usage ;;

  esac
done

for x in $(find . -name "*.tick"); do 
  tick=$(basename $x)
  serv=${tick%%.tick}

  [ ! "$DEFINE" -a ! "$ENABLE" ] && {
    usage
  }

  echo "start $serv .."
  # define tasks
  [[ "$DEFINE" ]] && kapacitor define $serv -tick $x

  [[ "$ENABLE" ]] && kapacitor enable $serv
done
