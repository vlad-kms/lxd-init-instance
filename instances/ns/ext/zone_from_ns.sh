#!/bin/bash

args=$(getopt -u -o 'a:d:s:' --long 'alias:,dest-path:,start:' -- "$@")
set -- $args
#echo $args
i=0
for i; do
  case "$i" in
    '-a' | '--alias')       ALIAS=${2};       shift 2 ;;
    '-d' | '--dest-path')   DEST_PATH=${2};   shift 2 ;;
    '-s' | '--start')       START_AFTER=${2}; shift 2 ;;
    else )                  exit 0;;
  esac
done


ALIAS=${ALIAS:=ns}
DEST_PATH=${DEST_PATH:=../files/var/bind}
START_AFTER=${START_AFTER:=0}
echo $ALIAS
#exit


lxc exec ${ALIAS} -- sh -c "rndc sync -clean && rc-service named stop"

d=( $(lxc exec ${ALIAS} -- find /var/bind -maxdepth 1 -name "db*") )
for el in ${d[@]}; do
  echo "lxc file pull -p ${ALIAS}$el ${DEST_PATH}"
  lxc file pull -p ${ALIAS}$el ${DEST_PATH}
done
if [[ $START_AFTER -ne 0 ]]; then
  lxc exec ${ALIAS} rc-service named start
fi
