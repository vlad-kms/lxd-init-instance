#!/bin/bash

#. func.sh

test_cloud_init_status() {
# $1 имя инстанса
# $2 статус, по-умолчанию 'done'
# Возврат:
# 0 - если нет ошибок и статус cloud-init в инстансе == $2
# 1 - иначе 
  st=$2
  st=${st:=done}
  r=$(${lxc_cmd} exec $1 -- cloud-init status --long)
  if [[ "$?" != "0" ]]; then
    # если ошибка образения к инстансу
    return 1
  fi
  r=$(echo $r | grep -e "^status:" | cut -c 9-12)
  if [[ "$?" != "0" ]] ; then
    # ошибка выполнеия вырезки и сравнения строки
    return 1
  fi
  if [[ "$r" == "$st" ]]; then
    # проверка статуса выполнения cloud-init
    return 0
  fi
  return 1
}

test_cloud_init_done() {
  test_cloud_init_status $fn 'done1'
  return $?
}

status_cloud_init_tm(){
  test_cloud_init_done
  res=$?
  x=1
  while [ ! $res -eq 0 ]
  do
    sd=`date`
    debug "${sd}"
    sleep 3
    x=$(( $x + 3 ))
    if [ $x -gt $TIMEOUT ]
    then
      res=250
      break
    fi

    test_cloud_init_done
    res=$?
  done
  return $res

}
