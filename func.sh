#!/bin/bash

#source global_vars.sh
source hook.sh

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
    -w, --where-copy DirName    - куда сделать бэкап данных из контейнера
    --use-name Number           - <>0 - добавлять в конце к каталогу $where_copy имя контейнера
                                  иначе не добавлять. По-умолчанию = 1
    --use-dir_cfg Number        - <>0 - добавлять в начале к каталогу $DEF_WHERE_COPY $dir_cfg, т.е. каталог будет ($dir_cfg/$DEF_WHERE_COPY),
                                  иначе не добавлять. По-умолчанию = 0
    -x, --export                - экспорт образ контейнера
  "
}

debug() {
  level=$2
  level=${level:=$DEBUG_LEVEL}
  if [[ $DEBUG -ne 0 ]]; then
    echo "deb::: $1"
  fi
}

########################################
# Вывести строку и прервать выполнение скрипта
# Вход:
#     $1 - код строки из массива $msg_arr
#     $2 - дополнительная строка для вывода
########################################
break_script() {
  item_msg_err $1
  [[ -z $2 ]] || echo $2
  exit $1
}

########################################
# Сделать рендеринг файла с помощью eval
# Вход:
#     $1 - имя файла для рендеринга
# Выход:
#     строка после рендеринга
########################################
template_render() {
  eval "echo \"$(cat $1)\""  
}

confgi_yaml_render() {
  echo "123"
}

########################################
# restart container
########################################
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
  #exit 1
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

# $1 --- имя контейнера или имя каталога. Как имя контейнера может содержать ':'.
#        поэтому будет вырезано имя каталога, все что после ':'
# Возврат $1 (DEF_DIR_CONFIGS/$1), если он существет и является каталогом. Иначе возврат ''
find_dir_in_location() {
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
### Удаление контейнера
  ### делаем backup контейнера, если $NOT_BACKUP_BEFORE_DELETE ==0
  ret_code=0
  if [ $NOT_BACKUP_BEFORE_DELETE -eq 0 ]; then
    debug "--- Бэкап данных из контейнера ${CONTAINER_NAME}"
    backup_data_instance
  fi
  if [[ ret_code -gt 0 ]]; then
    # если ошибка после бэкапа
    debug "Error after backup"
  fi

  ### удалить контейнер
  # ловушка перед удалением контейнера
  # из ловушки должен возвращаться $ret_code:
  # =0  - продолжить стандартную работу: удаление, ловушка после удаления
  # =1  - удаление, пропустить ловушку после удаления
  # =2  - пропустить удаление, вызвать ловушку после удаления
  # >=3 - пропустить удаление, пропустить ловушку после удаления
  debug '--- source ${dir_cfg}/${DEF_HOOK_BEFOREDELETE}'
  ([[ -n ${dir_cfg} ]] && [[ -d ${dir_cfg} ]] && [[ -f ${dir_cfg}/${DEF_HOOK_BEFOREDELETE} ]]) && source ${dir_cfg}/${DEF_HOOK_BEFOREDELETE}
  
  if [ $ret_code -eq 0 ]; then
    debug "ret_code: $ret_code"
    debug "--- $lxc_cmd delete --force ${CONTAINER_NAME}"
    [ $DEBUG_LEVEL -lt 90 ] && $lxc_cmd delete --force ${CONTAINER_NAME}
    [[ $? -ne 0 ]] && break_script $ERR_DELETE_CONTAINER
  elif [ $ret_code -eq 1 ]; then
    debug "ret_code: $ret_code"
    debug "--- $lxc_cmd delete --force ${CONTAINER_NAME}"
    [ $DEBUG_LEVEL -lt 90 ] && $lxc_cmd delete --force ${CONTAINER_NAME}
    [[ $? -ne 0 ]] && break_script $ERR_DELETE_CONTAINER
    $ret_code=0
    return
  elif [ $ret_code -eq 2 ]; then
    debug "ret_code: $ret_code"
  else
    debug "ret_code: $ret_code"
    return
  fi
  [[ -z ${ret_message} ]] || echo "${ret_message}"

    # ловушка после удаления контейнера
  debug '--- source ${dir_cfg}/${DEF_HOOK_AFTERDELETE}'
  ([[ -n ${dir_cfg} ]] && [[ -d ${dir_cfg} ]] && [[ -f ${dir_cfg}/${DEF_HOOK_AFTERDELETE} ]]) && source ${dir_cfg}/${DEF_HOOK_AFTERDELETE}

}

backup_data_instance() {
  ### делаем backup контейнера
  ret_code=0
  debug "--- Бэкап данных из контейнера ${CONTAINER_NAME}"
  [[ -z ${CONTAINER_NAME} ]] && break_script ${ERR_BAD_ARG_NOT_CONATINER_NAME}
  [[ ! -f ${dir_cfg}/${DEF_SCRIPT_BACKUP} ]] && break_script ${ERR_NOT_SCRIPT_BACKUP}
  debug "--- Выполнить ${dir_cfg}/${DEF_SCRIPT_BACKUP}"
  [[ $DEBUG_LEVEL -lt 90 ]] && source ${dir_cfg}/${DEF_SCRIPT_BACKUP}
  # после выхода из скрипта $ret_code содержит код ошибки
  # =0        - нет ошибки
  # >0 && <11 - передать код $ret_code дальше вверх про стеку выполнения
  # >10 - прервать выполнение скрипта и вывести сообщения из msg_arr[ret_code] и $ret_message
  [[ $ret_code -ge 11 ]] && break_script ${ret_code} "${ret_message}"
}

########################################
# Проверить существование функции
# Вход:
#     $1  - имя функции для проверки
# Выход:
#     return 0    - если не существует
#     echo "not"
#     return 1    - если существует
#     echo "exist"
########################################
is_exists_func() {
  if [[ -z $1 ]]; then
    echo "not"
    return 0
  fi
  declare -F ${1} > /dev/null && {
    echo "exists"
    return 1
  }
  echo "no"
  return 0
}

#####################################################
# Проверить существует ли контейнер
# Вход:
#     $1 - имя контейнера
# Выход:
#     =1 - контейнер существует
#     =0 - контейнер не существует
#####################################################
# TODO. Не тспользуется. Можно удалить.
#is_exists_instance() {
#  [[ -z $1 ]] && return 0
#  ret=$(lxc info $1 2> /dev/null)
#  [[ $? -eq 0 ]] && return 1 || return 0
#}

#####################################################
# Вернуть состояние контейнера (STOPPED || RUNNING || NOT_EXISTS)
# Вход:
#     $1 - имя контейнера
# Выход:
#     echo $state - состояние контейнера, (STOPPED || RUNNING || NOT_EXISTS)
#     return 1 - контейнер существует
#     return 0 - контейнер не существует
#####################################################
state_instance() {
  [[ -z $1 ]] && {
    echo 'NOT_EXISTS'
    return 0
  }
  ret=$(lxc info $1 2> /dev/null | grep 'Status:')
  [[ $? -ne 0 ]] && {
    echo 'NOT_EXISTS'
    return 0
  }
  echo $ret | sed -n -e 's/Status:[[:blank:]]*\([[:graph:]]*\)$/\1/p'
  return 1
}

#####################################################
#####################################################
is_running_instance() {
  ret=$(state_instance $1)
  [[ "$ret" == "RUNNING" ]] && echo "1" || echo ''
}
#####################################################
# Экспорт контейнера
#####################################################
export_instance() {
  debug "Экспорт контейнера ${CONTAINER_NAME}"
  is_running=$(is_running_instance ${CONTAINER_NAME})
  # ловушка перед lxc stop и lxc export
  hook_dispath 'hooks' 'before_export'

  #[[ $DEBUG_LEVEL -lt 90 ]] && [[ $is_running -eq 1 ]] && $lxc_cmd stop ${CONTAINER_NAME}
  #[[ $DEBUG_LEVEL -lt 90 ]] && $lxc_cmd export ${CONTAINER_NAME} "$(last_char_dir ${where_copy})$(get_part_from_container_name ${CONTAINER_NAME} h)-$(get_part_from_container_name ${CONTAINER_NAME})-image-container.tar.gz"
  #[[ $DEBUG_LEVEL -lt 90 ]] && [[ $is_running -eq 1 ]] && $lxc_cmd start ${CONTAINER_NAME}

  # ловушка после lxc export и lxc start
  #lxc export ns /root/ns.tar.gz
  hook_dispath 'hooks' 'after_export'
}

last_char_dir() {
  [[ -z $1 ]] && {
    return
  }
  s=${1}
  l=${#s}
  act=$2; act=${act:='add'}
  ( [[ "${act}" == "add" ]] || [[ "${act}" == "del" ]] || [[ "${act}" == "get" ]] ) || act='add'
  case "$act" in
    add)
      [[ "${s: -1}" != "/" ]] && s="${s}/"
      ;;
    del)
      [[ "${s: -1}" == "/" ]] && s="${s:0:$((l - 1))}"
      ;;
    get)
      echo "${s: -1}"
      ;;
    *) break_script ${ERR_BAD_ACTION_LASTCHAR_DIR} ;;
  esac
  echo "${s}"
}

test_func_sh(){
  #echo $(get_part_from_container_name 'hhh:ccc' 'h')
  #echo $(get_part_from_container_name 'hhh:ccc')

  #last_char_dir
  #last_char_dir dir/1
  #last_char_dir dir/1 add
  #last_char_dir dir/1/
  #last_char_dir dir/1/ add
  #echo '================='
  #last_char_dir dir/1 del
  #last_char_dir dir/1/ del
  
  #last_char_dir dir/1 get
  #last_char_dir dir/1/ get

  #state_instance lxd-dev:tst2
  #state_instance lxd-dev:tst3
  #state_instance lxd-dev:tst4

  #t=$(is_running_instance lxd-dev:tst2)
  #[[ "$t" == "1" ]] && echo RUNNING || echo HZ
  #[[ $(is_running_instance lxd-dev:tst3) == "1" ]] && echo RUNNING || echo HZ
  #[[ $(is_running_instance lxd-dev:tst4) == "1" ]] && echo RUNNING || echo HZ

  CONTAINER_NAME=/lxd-dev:tst3
  DEBUG_LEVEL=90
  DEBUG=0
  #export_instance

  #echo $(is_exists_func test_func_sh)
  #ret=$?
  #echo $ret
  #echo $(is_exists_func test_func_sh1)
  #ret=$?
  #echo $ret
  #echo 123 > /dev/null;

  dir_cfg='instances/tst3/'
  hook_dispath "export"


}

#test_func_sh
