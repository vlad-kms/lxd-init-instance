#!/bin/bash

#TESTING=1
#if [[ $TESTING -ne 0 ]]; then
#  CONTAINER_NAME="lxd-dev:ansible"
#  where_copy="backup/"
#  echo 123
#  #exit
#fi

#lxc -q exec ${CONTAINER_NAME} -- sh -c "tar -czf /root/backup.tar.gz --exclude=.git /root/1/1 /root/2/1 > /dev/null 2>/dev/null"
lxc -q exec ${CONTAINER_NAME} -- sh -c "tar -czf /root/backup.tar.gz --exclude=.git /root/1/1 /root/2/1 2>&1 | grep -v  'Removing leading'"
#lxc -q exec ${CONTAINER_NAME} -- sh -c "tar -czf /root/backup.tar.gz -C /root/1/1 /root/2/1"
ret_code=$?
if [[ ret_code -eq 0 ]]; then
  lxc file pull -q -p ${CONTAINER_NAME}/root/backup.tar.gz ${where_copy}
  ret_code=$?
  [ $ret_code -ne 0 ] && ret_message="Ошибка копирования данных"
else
  ret_message="Ошибка архивирования данных"
fi
