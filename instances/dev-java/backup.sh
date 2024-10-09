#!/bin/bash

#/etc/apache2/conf-available/nagios4-cgi.conf
#/etc/apache2/mods-available/mime.conf
#/etc/nagios4/*
#/root/.config/*
#/root/.ssh/*
#/root/.bash_history
#/root/.bashrc
#/root/.profile

#exit 0

name_tar="${1}"
dt="$(date +"%Y%m%d-%H%M%S")-"
#unset dt
name_tar="${name_tar:=${dt}named.tar.gz}"
name_tar="/root/$name_tar"
echo "$0 - name_tar: $name_tar" >&2

# shellcheck disable=SC2154
$lxc_cmd -q exec "${CONTAINER_NAME}" -- sh -c "tar -czf ${name_tar} /root/* #> /dev/null 2> /dev/null"
ret=$?
if [[ $ret -eq 0 ]]; then
  # shellcheck disable=SC2154
  $lxc_cmd file pull -q -p "${CONTAINER_NAME}${name_tar}" "${where_copy}"
  ret=$?
  if [[ $ret -ne 0 ]]; then
    ret_message="Ошибка при копировании файлов"
    ret_code=1000
  fi
  $lxc_cmd exec "${CONTAINER_NAME}" -- rm "${name_tar}"
else
  ### ошибка поиска файлов
  # shellcheck disable=SC2034
  ret_message="Ошибка поиска файлов"
  # shellcheck disable=SC2034
  ret_code=1000
fi
