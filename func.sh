#!/bin/bash

#source global_vars.sh

help() {
  echo "
  Аргументы запуска:
        --add                   - действие 'add', создать новый контейнер
    -a, --alias AliasName       - имя (alias) контейнера
        --backup                - действие 'backup', копия данных из контейнера
    -c, --config-dir DirConf    - каталог с файлами конфигурации и инициализации контейнера
    -d, --delete                - действие 'delete', удалить контейнер
        --debug                 - выводить отладочную информацию
        --debug-level Number    - уровень отладочной информации
    -e, --env EnvName=EnvValue  - значения для переопределния переменных в файлах конфигурации
    -h, --help                  - вызов справки
    -i, --image InageName       - образ, с которого создать контейнер 
    -t, --timeout Number        - период ожидания в сек
    -u  --vaults FileName       - файл со значениями секретных переменных для сборки контейнера, которые не хранятся в git
    -v  --vars FileName         - файл со значениями переменных для сборки контейнера, которые хранятся в git
  "
}

debug() {
  level=$2
  level=${level:=$DEBUG_LEVEL}
  if [ $DEBUG -ne 0 ]; then
    echo "deb::: $1"
  fi
}

template_render() {
  eval "echo \"$(cat $1)\""  
}

confgi_yaml_render() {
  echo "123"
}

restart_instance() {
  debug "=== restarting instance"
  ${lxc_cmd} stop $CONTAINER_NAME
  ${lxc_cmd} start $CONTAINER_NAME
}

add2array_env(){
  echo $array_env
}

create_container() {
# $1 --- $IMAGE_NAME
# $2 --- ${config_file_render}
  if [[ -z $1 ]]; then
    exit 110
  fi
  if [[ -z $2 ]]; then
    ${lxc_cmd} init ${1}        | sed -ne 's/Instance name is:[[:blank:]]*\([[:graph:]]*\)$/\1/p'
  else
    ${lxc_cmd} init ${1} < ${2} | sed -ne 's/Instance name is:[[:blank:]]*\([[:graph:]]*\)$/\1/p'
  fi
}

on_error() {
  ([[ -n "${tmpfile}" ]]  && [[ -f "${tmpfile}" ]])  && rm "${tmpfile}"
  ([[ -n "${tmpfile1}" ]] && [[ -f "${tmpfile1}" ]]) && rm "${tmpfile1}"
}

find_dir_in_location() {
# $1 --- имя контейнера или имя каталога. Как имя контейнера может содержать ':'.
#        поэтому будет вырезано имя каталога, все что после ':'
# Возврат $1 (DEF_DIR_CONFIGS/$1), если он существет и является каталогом. Иначе возврат ''
  tdc=${1}
  ### убрать из имени каталога имя сервера, если имя контейнера было как server:container
  [[ "${tdc}" =~ ":" ]] && tdc=$(echo ${tdc} | sed -n -e  's/\(.*\):\(.*\)/\2/p')
  # вернуть имя каталога, если он существует в ./
  if ([[ -n "$tdc" ]] && [[ -d "$tdc" ]]); then
    echo $tdc
  else
    tdc=${DEF_DIR_CONFIGS}/${tdc}
    # вернуть имя каталога, если он существует в DEF_DIR_CONFIGS, иначе вернуть ''
    ([[ -n "$tdc" ]] && [[ -d "$tdc" ]]) && echo $tdc || echo ''
  fi
}
