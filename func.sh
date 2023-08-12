#!/bin/bash

#source global_vars.sh

help() {
  echo "
  Аргументы запуска:
        --add                   - действие 'add', создать новый контейнер
    -a, --alias AliasName       - имя (alias) контейнера
    -b, --backup                - действие 'backup', копия данных из контейнера
    -c, --config-dir DirConf    - каталог с файлами конфигурации и инициализации контейнера
    -d, --delete                - действие 'delete', удалить контейнер
        --debug                 - выводить отладочную информацию
        --debug-level Number    - уровень отладочной информации
    -e, --env EnvName=EnvValue  - значения для переопределния переменных в файлах конфигурации
    -h, --help                  - вызов справки
    -i, --image InageName       - образ, с которого создать контейнер 
    -n, --not-backup            - если =0, то бэкап перед удалением контейнера, иначе нет бэкапа. По-умолчанию =0.
    -t, --timeout Number        - период ожидания в сек
    -u, --vaults FileName       - файл со значениями секретных переменных для сборки контейнера, которые не хранятся в git
    -v, --vars FileName         - файл со значениями переменных для сборки контейнера, которые хранятся в git
    -w, --where-copy            - куда сделать бэкап данных из контейнера
  "
}

debug() {
  level=$2
  level=${level:=$DEBUG_LEVEL}
  if [ $DEBUG -ne 0 ]; then
    echo "deb::: $1"
  fi
}

break_script() {
  if [[ $1 -lt 1000 ]]; then
    item_msg_err $1
  else
    echo $2
  fi
  exit $1
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

get_part_from_container_name() {
  host_lxc=$(echo $1 | sed -n -e  's/\(.*\):\(.*\)/\1/p')
  container_lxc=$(echo $1 | sed -n -e  's/\(.*\):\(.*\)/\2/p')
  r=$2
  r=${r:="c"}
  case "$r" in
    'h')  echo $host_lxc;
      ;;
#    'c') echo $container_lxc;
#      ;;
    *) echo $container_lxc;
      ;;
  esac
}

find_dir_in_location() {
# $1 --- имя контейнера или имя каталога. Как имя контейнера может содержать ':'.
#        поэтому будет вырезано имя каталога, все что после ':'
# Возврат $1 (DEF_DIR_CONFIGS/$1), если он существет и является каталогом. Иначе возврат ''
  tdc=${1}
  ### убрать из имени каталога имя сервера, если имя контейнера было как server:container
  #[[ "${tdc}" =~ ":" ]] && tdc=$(echo ${tdc} | sed -n -e  's/\(.*\):\(.*\)/\2/p')
  [[ "${tdc}" =~ ":" ]] && tdc=$(get_part_from_container_name $tdc)
  # вернуть имя каталога, если он существует в ./
  if ([[ -n "$tdc" ]] && [[ -d "$tdc" ]]); then
    echo $tdc
  else
    tdc=${DEF_DIR_CONFIGS}/${tdc}
    # вернуть имя каталога, если он существует в DEF_DIR_CONFIGS, иначе вернуть ''
    ([[ -n "$tdc" ]] && [[ -d "$tdc" ]]) && echo $tdc || echo ''
  fi
}

delete_instance() {
  ### делаем backup контейнера, если $NOT_BACKUP_BEFORE_DELETE ==0
  if [ $NOT_BACKUP_BEFORE_DELETE -eq 0 ]; then
    debug "--- Бэкап данных из контейнера ${CONTAINER_NAME}"
    backup_instance
  fi
  
  ### удалить контейнер
  # ловушка перед удалением контейнера
  ret_code=0
  debug '--- ret_code=$(source ${dir_cfg}/${DEF_HOOK_BEFOREDELETE})'
  ([[ -n ${dir_cfg} ]] && [[ -d ${dir_cfg} ]] && [[ -f ${dir_cfg}/${DEF_HOOK_BEFOREDELETE} ]]) && source ${dir_cfg}/${DEF_HOOK_BEFOREDELETE}
  
  if [ $ret_code -lt 10 ]; then
    debug "--- $lxc_cmd delete --force ${CONTAINER_NAME}"
    #$lxc_cmd delete --force ${CONTAINER_NAME}
    ret_code=$?
    [[ $ret_code -ne 0 ]] && break_script $ret_code
  elif [ $ret_code -eq 11 ]; then
    debug "ret_code: $ret_code"
    #$lxc_cmd delete --force ${CONTAINER_NAME}
    return
  else
    debug "ret_code: $ret_code"
  fi
  # ловушка после удаления контейнера
  debug '--- source ${dir_cfg}/${DEF_HOOK_AFTERDELETE}'
  ([[ -n ${dir_cfg} ]] && [[ -d ${dir_cfg} ]] && [[ -f ${dir_cfg}/${DEF_HOOK_AFTERDELETE} ]]) && {
    source ${dir_cfg}/${DEF_HOOK_AFTERDELETE}
  }
}

backup_instance() {
  ### делаем backup контейнера
  ret_code=0
  debug "--- Бэкап данных из контейнера ${CONTAINER_NAME}"
  [[ -z ${CONTAINER_NAME} ]] && break_script ${ERR_BAD_ARG_NOT_CONATINER_NAME}
  [[ ! -f ${dir_cfg}/${DEF_SCRIPT_BACKUP} ]] && break_script ${ERR_NOT_SCRIPT_BACKUP}
  debug "--- Выполнить ${dir_cfg}/${DEF_SCRIPT_BACKUP}"
  source ${dir_cfg}/${DEF_SCRIPT_BACKUP}
  [[ $ret_code -ne 0 ]] && break_script ${ret_code} "${ret_message}"
}

#echo $(get_part_from_container_name 'hhh:ccc' 'h')
#echo $(get_part_from_container_name 'hhh:ccc')
