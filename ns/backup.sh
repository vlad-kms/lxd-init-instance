#!/bin/bash

lxc -q exec ${CONTAINER_NAME} -- sh -c "rndc sync -clean && rc-service named stop"
ret_code=$?
if [[ $ret_code -eq 0 ]]; then
  d=( $(lxc -q exec ${CONTAINER_NAME} -- find /var/bind -maxdepth 1 -name "db*") )
  ret_code=$?
  [[]]

for el in ${d[@]}; do
  #echo "${lxc_cmd} file pull -p ${CONTAINER_NAME}$el ${where_copy}"
  lxc -q file pull -p ${CONTAINER_NAME}$el ${where_copy}
done
if [[ $START_AFTER -ne 0 ]]; then
  lxc -q exec ${CONTAINER_NAME} rc-service named start
fi

else
  ### ошибка остановки сервиса named
  ret_message="Ошибка остановки сервиса named (bind9)"
  ret_code=300
  return
fi

