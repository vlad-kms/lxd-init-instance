#!/bin/bash

#/etc/apache2/conf-available/nagios4-cgi.conf
#/etc/apache2/mods-available/mime.conf
#/etc/nagios4/*
#/root/.config/*
#/root/.ssh/*
#/root/.bash_history
#/root/.bashrc
#/root/.profile

name_tar=/root/named.tar.gz
#force_backup=1

# /etc/bind
lxc -q exec ${CONTAINER_NAME} -- sh -c "tar -czf ${name_tar} /etc/apache2/conf-available/nagios4-cgi.conf /etc/apache2/mods-available/mime.conf /etc/nagios4/* /usr/lib/nagios/*.sh /etc/exim4/* /root/.config/* /root/.ssh/* /root/.bash_history /root/.bashrc /root/.profile > /dev/null"
if [[ $? -eq 0 ]]; then
  lxc file pull -q -p ${CONTAINER_NAME}${name_tar} ${where_copy}
  if [[ $? -ne 0 ]]; then
    ret_message="Ошибка при копировании файлов"
    ret_code=1000
  fi
else
  ### ошибка поиска файлов
  ret_message="Ошибка поиска файлов"
  ret_code=1000
fi

