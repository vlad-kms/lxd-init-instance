#!/bin/bash

#TESTING=1
#if [[ $TESTING -ne 0 ]]; then
#  CONTAINER_NAME="lxd-dev:ansible"
#  where_copy="backup/"
#  echo 123
#  #exit
#fi

lxc -q exec ${CONTAINER_NAME} -- tar -czf /root/pb-home.tar.gz --exclude=.git /root/pb-home/
ret_code=$?
if [[ ret_code -eq 0 ]]; then
  lxc file pull -q -p ${CONTAINER_NAME}/root/pb-home.tar.gz ${where_copy}
  ret_code=$?
  [ $ret_code -ne 0 ] && ret_message="Ошибка копирования данных"
else
  ret_message="Ошибка архивирования данных"
fi
