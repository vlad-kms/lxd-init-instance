#!/bin/bash

#name_tar=/root/named.tar.gz
force_backup=1

exit 1

name_tar="${1}"
dt="$(date +"%Y%m%d-%H%M%S")-"
name_tar="${name_tar:=${dt}named.tar.gz}"
name_tar="/root/$name_tar"
echo "$0 - name_tar: $name_tar"

lxc -q exec ${CONTAINER_NAME} -- sh -c "rndc sync -clean > /dev/null && rc-service named stop > /dev/null"
if [[ $? -eq 0 ]] || [[ $force_backup -ne 0 ]]; then
  # /etc/bind
  lxc -q exec ${CONTAINER_NAME} -- sh -c "tar -czf ${name_tar} --exclude=*.jnl /etc/bind/named.conf \
    /etc/bind/named.conf.local /etc/bind/named.conf.options /var/bind/named.conf.lan-zone /var/bind/named.conf.acl \
    /var/bind/db* > /dev/null 2> /dev/null"
  if [[ $? -eq 0 ]]; then
    lxc file pull -q -p ${CONTAINER_NAME}${name_tar} ${where_copy}
    if [[ $? -eq 0 ]]; then
      lxc exec ${CONTAINER_NAME} -q -- sh -c "rc-service named start > /dev/null"
      if [[ $? -ne 0 ]]; then
        ret_message="Ошибка запуска сервиса named (bind9)"
        ret_code=1000
      fi
    else
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
fi

