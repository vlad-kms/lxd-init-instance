#!/bin/bash

lxc -q exec ${CONTAINER_NAME} -- sh -c "rndc sync -clean > /dev/null && rc-service named stop > /dev/null"
ret_code=$?
if [[ $ret_code -eq 0 ]]; then
  d=( $(lxc exec ${CONTAINER_NAME} -q -- find /var/bind -maxdepth 1 -name "db*") )
  ret_code=$?
  if [[ $ret_code -eq 0 ]]; then
    for el in ${d[@]}; do
      #echo "${lxc_cmd} file pull -p ${CONTAINER_NAME}$el ${where_copy}"
      lxc file pull -q -p ${CONTAINER_NAME}$el ${where_copy}
      ret=$?
      [[ $ret -ne 0 ]] && ret_code=$ret
    done
    lxc exec ${CONTAINER_NAME} -q -- sh -c "rc-service named start > /dev/null"
    if [[ $ret_code -ne 0 ]]; then
      ret_message="Ошибка при копировании файлов"
      ret_code=1000
    fi
  else
    ### ошибка поиска файлов
    ret_message="Ошибка поиска файлов"
    ret_code=1000
  fi
else
  ### ошибка остановки сервиса named
  ret_message="Ошибка остановки сервиса named (bind9)"
  ret_code=1000
  #return
fi

