#!/bin/bash
#common.sh
# shellcheck disable=SC2059

#############################################
# Вызов справки
#############################################
help() {
  echo "
  Аргументы запуска:
        --add                   - действие 'add', создать новый контейнер
    -a, --alias AliasName       - имя (alias) контейнера
    -b, --backup                - действие 'backup', копия данных из контейнера
    -c, --config-dir DirConf    - каталог с файлами конфигурации и инициализации контейнера
    --cipher-file-dir           - начальный каталог для поиска файлов для шифрования
    --cipher-file-name          - маска файлов для поиска
    -d, --delete                - действие 'delete', удалить контейнер
        --debug                 - выводить отладочную информацию
        --debug-level Number    - уровень отладочной информации
        --decode-file           - дешифровать файл \"FileName-enc\" и сохранить в \"FileName\"
        --encode-file           - шифровать файл \"FileName\" и сохранить в \"FileName-enc\"
    -e, --env EnvName=EnvValue  - значения для переопределния переменных в файлах конфигурации
    -h, --help                  - вызов справки
    -i, --image InageName       - образ, с которого создать контейнер
    -n, --not-backup            - если =0, то бэкап перед удалением контейнера, иначе нет бэкапа. По-умолчанию: 0.
    -p, --pass_file             - файл с паролем. Действительна только первая строка. По-умолчанию: ./secrets/cipher_pass 
    -t, --timeout Number        - период ожидания в сек
    -u, --vaults FileName       - файл со значениями секретных переменных для сборки контейнера, которые не хранятся в git
    -v, --vars FileName         - файл со значениями переменных для сборки контейнера, которые хранятся в git
    -w, --where-copy DirName    - куда сделать бэкап данных из контейнера
    --use-name Number           - <>0 - добавлять в конце к каталогу where_copy имя контейнера
                                  иначе не добавлять. По-умолчанию = 1
    --use-dir_cfg Number        - <>0 - добавлять в начале к каталогу $DEF_WHERE_COPY dir_cfg, т.е. каталог будет dir_cfg/DEF_WHERE_COPY),
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
  item_msg_err "$1"
  [[ -z $2 ]] || echo "$2"
  exit "$1"
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
  ret=$(lxc info "$1" 2> /dev/null | grep 'Status:')
  [[ $? -ne 0 ]] && {
    echo 'NOT_EXISTS'
    return 0
  }
  echo "$ret" | sed -n -e 's/Status:[[:blank:]]*\([[:graph:]]*\)$/\1/p'
  return 1
}

#####################################################
# Проверить контейнер запущен или нет
# Вход:
#     $1 - имя контейнера
# Выход:
#     echo "1" - контейнер запущен
#     echo ""  - контейнер не запущен
#####################################################
is_running_instance() {
  ret=$(state_instance "$1")
  [[ "$ret" == "RUNNING" ]] && echo "1" || echo ''
}

########################################
# restart container
# Вход:
#     $1 - имя контейнера
########################################
restart_instance() {
  debug "=== restarting instance"
  state_instance=$(state_instance "$1")
  [[ "${state_instance}" != "NOT_EXISTS" ]] && {
     [[ "${state_instance}" = "RUNNING" ]] &&  "${lxc_cmd}" stop "$1"
    "${lxc_cmd}" start "$1"
  }
}

########################################
# Сделать рендеринг файла с помощью eval
# Вход:
#     $1 - имя файла для рендеринга
# Выход:
#     строка после рендеринга
########################################
template_render() {
  eval "echo \"$(cat "$1")\""
}

#############################################
# Вернуть часть имени контейнера: имя хоста или имя контейнера.
# host:container
# Вход:
#     $1  - имя контейнера для разбора
#     $2  - что вернуть: имя контейнера или имя хоста
#           ='h' , имя хоста (host)
#           = 'c', имя контейнера (container)
#           иначе, имя контейнера (container)
#           по-умолчанию = 'c', т.е. вернуть имя контейнера
# Выход:
#     echo "host" || echo "container"
#############################################
get_part_from_container_name() {
  host_lxc=$(echo "$1" | sed -n -e      's/\(.*\):\(.*\)/\1/p')
  if [ -z "$host_lxc" ]; then
    container_lxc="$1"
  else
    container_lxc=$(echo "$1" | sed -n -e 's/\(.*\):\(.*\)/\2/p')
  fi
  r=$2
  r=${r:="c"}
  case "$r" in
    'h')  echo "$host_lxc";
      ;;
    'c') echo "$container_lxc";
      ;;
    *) echo "$container_lxc";
      ;;
  esac
}

#################################################################
# Поиск каталога с файлами конфигурации для инстанса.
# $1 может быть 'name_container' или 'host:name_container'
# Если $1 передан в виде 'host:name_container', то преобразуется к 'name_container'
# Ищет каталог с именем 'name_container' сначала в ./ (каталоге запуска скрипта),
# затем если не найден, в ./instances. 
# Вход:
#   $1 --- имя контейнера или имя каталога. Как имя контейнера может содержать ':'.
#          поэтому будет вырезано имя каталога, все что после ':'
# Выход:
#   echo "name_container" ||
#   echo "instances/name_container" , если он существует и является каталогом.
#   echo ''                         , если не существует или не является каталогом.
#################################################################
find_dir_in_location() {
  tdc=${1}
  ### убрать из имени каталога имя сервера, если имя контейнера было как server:container
  #[[ "${tdc}" =~ ":" ]] && tdc=$(echo ${tdc} | sed -n -e  's/\(.*\):\(.*\)/\2/p')
  [[ "${tdc}" =~ ":" ]] && tdc=$(get_part_from_container_name "$tdc")
  # вернуть имя каталога, если он существует в ./
  if [[ -n "$tdc" ]] && [[ -d "$tdc" ]]; then
    echo "$tdc"
  else
    tdc=${DEF_DIR_CONFIGS}/${tdc}
    # вернуть имя каталога, если он существует в DEF_DIR_CONFIGS, иначе вернуть ''
    { [ -n "$tdc" ] && [ -d "$tdc" ]; } && echo "$tdc" || echo ''
  fi
}

#################################################################
# Проверить существование функции
# Вход:
#     $1  - имя функции для проверки
# Выход:
#     return 0    - если не существует
#     echo "not"
#     return 1    - если существует
#     echo "exist"
#################################################################
is_exists_func() {
  if [[ -z $1 ]]; then
    echo "not"
    return 0
  fi
  declare -F "${1}" > /dev/null && {
    echo "exists"
    return 1
  }
  echo "not"
  return 0
}

#################################################################
# Возврат, изменение последнего символа в имени каталога
# Вход:
#   $1 ---- имя каталога.
#   $2 ---- действие, что делать:
#           add - добавить к имени каталога $1 '/', если в конце этого символа нет
#           del - удалить в конце имени каталога $1 '/', если в конце есть этот символ
#           get - вернуть последний символ в имени каталога $1
# Выход:
#   echo 'dir_name'   - имя каталога
#   echo 'last_char'  - последний символ в переданном имени каталога
#################################################################
last_char_dir() {
  [[ -z $1 ]] && {
    return
  }
  s=${1}
  l=${#s}
  act=$2; act=${act:='add'}
  { { [ "$act" == "add" ] || [ "$act" == "del" ]; } || [ "$act" == "get" ]; } || act='add'
  case "$act" in
    add)
      [[ "${s: -1}" != "/" ]] && s="${s}/"
      ;;
    del)
      # удалить все символы '/' в конце строки
      #echo "dsfsdf/sdfsdf//////"|sed -En "s/[\/]*$//p"
      # удалить символ '/' в конце строки
      [[ "${s: -1}" == "/" ]] && s="${s:0:$((l - 1))}"
      ;;
    get)
      echo "${s: -1}"
      ;;
    *) break_script "${ERR_BAD_ACTION_LASTCHAR_DIR}" ;;
  esac
  echo "${s}"
}



###########################################################
###########################################################
###########################################################
###########################################################
## TEST
###########################################################
test_common() {
  # shellcheck source-path=SCRIPTDIR
  source functions/global_vars.sh || source global_vars.sh

  #restart_instance "lxd-dev:tst23"
  #restart_instance "ns3"
  
  #get_part_from_container_name 'lxd:con'
}

#test_common
