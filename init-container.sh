#!/bin/bash

# подключение функций и глобальных переменных
source ./functions/global_vars.sh
source ./functions/common.sh
source hook.sh

#source func.sh
#source func-tm.sh

trap 'on_error' ERR

unset SCRIPT_NAME

####################################################################################
# СКРИПТ
####################################################################################

declare -a array_env

args=$(getopt -u -o 'a:bc:de:hi:nt:u:v:w:x' --long 'add,alias:,backup,config-dir:,debug,delete,env:,help,image:,not-backup,timeout:,vaults:,vars:,where-copy:,debug-level:,use-name:,use_dir_cfg:,export' -- "$@")
set -- $args
debug $args
i=0
for i; do
    case "$i" in
        '--add')                action="add";         shift;;
        '-a' | '--alias')       CONTAINER_NAME=${2};  shift 2;;
        '-b' | '--backup')      action="backup";      shift;;
        '-c' | '--config-dir')  CONFIG_DIR_NAME=${2}; shift 2;;
        '-d' | '--delete')      action="delete";      shift;;
        '--debug')              DEBUG=1;              shift;;
        '--debug-level')        DEBUG_LEVEL=$2;       shift 2;;
        '-e' | '--env')         array_env+=( $2 );    shift 2;;
        '-h' | '--help')        help; exit 0          ;;
        '-i' | '--image')       arg_image_name=${2};  shift 2;;
        '-n' | '--not-backup')  NOT_BACKUP_BEFORE_DELETE=1; shift;;
        '-p' | '--pass_file'    pass_file=${2};       shift 2;; 
        '-t' | '--timeout')     TIMEOUT=${2};         shift 2;;
        '-u' | '--vaults')      VAULTS_NAME=${2};     shift 2;;
        '-v' | '--vars')        VARS_NAME=${2};       shift 2;;
        '-w' | '--where-copy')  arg_where_copy=${2};  shift 2;;
        '--use-name')           use_name=${2};        shift 2;;
        '--use-dir_cfg')        use_dir_cfg=${2};     shift 2;;
        '-x' | '--export')      action="export";      shift;;
        else)                   help; exit 0          ;;
    esac
done
### --timeout, по-умолчанию = 60 сек
TIMEOUT=${TIMEOUT:=60}
action=${action:="add"}

### --pass_file (-p) начальная инициализация cipher шифрования
init_cipher $pass_file

### Подготовка командной строки в зависимости от ключа --debug
if [ "${DEBUG}" -eq 0 ]; then
  lxc_cmd="${lxc_cmd} -q"
else
  if [ $DEBUG_LEVEL -eq 1 ]; then
    lxc_cmd="${lxc_cmd}"
  elif [ ${DEBUG_LEVEL} -eq 2 ]; then
    lxc_cmd="${lxc_cmd} --debug"
  else
    lxc_cmd="${lxc_cmd} --debug"
  fi
fi

### разбор --alias и --config_dir
### есть --alias, есть --config_dir
### есть --alias, нет  --config_dir
### нет  --alias, есть --config_dir
###   ${lxc_cmd} launch < $CONFIG_DIR_NAME/$DEF_CFG_YAML
### нет  --alias, нет  --config_dir
###   ${lxc_cmd} launch < $DEF_GENERAL_CONFIG_DIR/$DEF_CFG_YAML
### Т.е. если нет --alias, то выполняется только одна команда ${lxc_cmd} launch < cfg_file .
### Запуск контейнера с файлом конфигурации, в котором можно использовать cloud-init, profiles и т.д.
### Если есть --alias, то полностью работает алгоритм, ради которого все это задумывалось

### Вычисляем каталог с файлами конфигурации контейнера
if [[ -n $CONFIG_DIR_NAME ]]; then
  ### если определен --config-dir, то каталог с конфигурацией == этому каталогу
  dir_cfg=${CONFIG_DIR_NAME}
else
  ### сначала ищем каталог по имени алиаса в ./ и ./instances,
  ### если такого нет, то ищем каталог general в ./ и ./instances
  ### если определен --alias
  CONFIG_DIR_NAME=${CONTAINER_NAME}
  [[ -n "${CONTAINER_NAME}" ]] && dir_cfg=${CONTAINER_NAME}
  [[ -n $dir_cfg ]] && dir_cfg=$(find_dir_in_location $dir_cfg)
  ### если нет каталога с именем контейнера, то попробовать каталог general
  if [[ -z $dir_cfg ]]; then
    dir_cfg=$(find_dir_in_location general)
    CONFIG_DIR_NAME=${dir_cfg}
  else
    CONFIG_DIR_NAME=${dir_cfg}
  fi
fi
### теперь $dir_cfg - каталог, где надо брать конфигурацию инстанса
### Проверить что $dir_cfg существует и является каталогом
### Если нет, то ошибка и прервать скрипт
if ! ([[ -n "$dir_cfg" ]] && [[ -d "$dir_cfg" ]]); then
  break_script ${ERR_BAD_ARG}
fi

### Подгружаем переменные
### Сначала из файла ИМЯСКРИПТА.conf
global_vars=${0}.conf
[[ -f "${global_vars}" ]] && source "${global_vars}"
### Теперь подгружаем переменные из каталога с конфигурацией инстанса
### ${dir_cfg}/${DEF_VARS_CONF} (vars.conf)
project_vars="${dir_cfg}/${DEF_VARS_CONF}"
[[ -f ${project_vars} ]] && source ${project_vars} || unset project_vars
### Если передали -v (--vars), то подгружаем переменные из файла переданного в этом параметре
arg_vars="${VARS_NAME}"
### Проверить что $arg_vars является файлом, если передан как аргумент
### Если не файл,но передан в аргументе, то ошибка и прервать скрипт
if ([[ -n "$arg_vars" ]] && [[ ! -f "$arg_vars" ]]);then
  break_script ${ERR_BAD_ARG_FILE_VARS_NOT}
fi
[[ -f ${arg_vars} ]] && source ${arg_vars} || unset arg_vars

### Теперь подгружаем секретные переменные из каталога с конфигурацией инстанса
### ${dir_cfg}/${DEF_VARS_VAULT} (vars.vault)
project_vault="${dir_cfg}/${DEF_VARS_VAULT}"
[[ -f ${project_vault} ]] && source ${project_vault} || unset project_vault
arg_vault="${VAULTS_NAME}"
### Проверить что $arg_vault является файлом, если передан как аргумент
### Если не файл, но передан в аргументе, то ошибка и прервать скрипт
if ([[ -n "$arg_vault" ]] && [[ ! -f "$arg_vault" ]]);then
  break_script ${ERR_BAD_ARG_FILE_SECRET_VARS_NOT}
fi
[[ -f ${arg_vault} ]] && source ${arg_vault} || unset arg_vault

### Теперь заменяем переменные, значениями переданными через командную строку (-e, --env)
for t in ${array_env[@]}; do
  eval $t
done

### Инициализация имени образа. Аргумент --image (-i) заменяет имя образа из файлов переменных
[[ -n "$arg_image_name" ]] && IMAGE_NAME=${arg_image_name}

### инитиализация имен файлов конфига, скриптов презапуска, запуска, послезапуска для контейнера
### файл конфигурации
#$(last_char_dir ${dir_cfg})
config_file="$(last_char_dir ${dir_cfg})${DEF_CFG_YAML}"
### если файла нет, то очистить переменную. Нет конфига
[[ -f ${config_file} ]] || unset config_file
### если файл cfg есть, то инит confgi_file_render,
### иначе очистить confgi_file_render
[[ -f ${config_file} ]] && config_file_render="${config_file}${POSTFIX_CFG_YAML_RENDER}" || unset config_file_render
# 104   - Не существует файл конфигурации контейнера
### Выход, если не существует файла конфигурации контейнера
[[ -f ${config_file} ]] || {
  #echo "Файл ${dir_cfg}/${DEF_CFG_YAML} не существует. Выполнение скрипта прервано";
  item_msg_err ${ERR_FILE_CONFIG_NOT}
  exit ${ERR_FILE_CONFIG_NOT}
}

### файл ловушки перед стартом инстанса
hooks_file=${hooks_file:=$DEF_HOOKS_FILE}
#hook_beforestart="${dir_cfg}/${DEF_HOOK_BEFORESTART}"
#[[ -f ${hook_beforestart} ]] || unset hook_beforestart
### файл ловушки после старта инстанса
#hook_afterstart="${dir_cfg}/${DEF_HOOK_AFTERSTART}"
#[[ -f ${hook_afterstart} ]] || unset hook_afterstart
### файл скрипта, выполняемого при старте инстанса
script_start="${dir_cfg}/${DEF_FIRST_SH}"
[[ -f ${script_start} ]] || unset script_start

### местоположение куда копировать бэкапы
[ $use_dir_cfg -ne 0 ] && pref="${dir_cfg}/" || pref=""
where_copy=${where_copy:=${pref}${DEF_WHERE_COPY}}
[[ -n $arg_where_copy ]] && where_copy=${arg_where_copy}
# последний символ не д.б. '/'
where_copy=$(last_char_dir "${where_copy}" del)
# добавить имя контейнера к пути бэкапа
[ ${use_name} -ne 0 ] && where_copy="${where_copy}/$(get_part_from_container_name ${CONTAINER_NAME} h)-$(get_part_from_container_name ${CONTAINER_NAME})"
# последний символ не д.б. '/'
where_copy=$(last_char_dir "${where_copy}" del)
# ошибка, если файл существует и не является каталогом
( [[  -a $f ]] && [[ ! -d $f ]] ) && break_script $ERR_NOT_DIR_WHERE_COPY
# последний символ д.б. '/'
where_copy=$(last_char_dir "${where_copy}" add)

debug "--------------------------------- argumentes"
debug "TIMEOUT:------------ $TIMEOUT"
debug "IMAGE_NAME:--------- $IMAGE_NAME"
debug "CONTAINER_NAME:----- $CONTAINER_NAME"
debug "CONFIG_DIR_NAME:---- $CONFIG_DIR_NAME"
debug "VARS_NAME:---------- $VARS_NAME"
debug "DEBUG--------------- $DEBUG"
debug "DEBUG_LEVEL--------- $DEBUG_LEVEL"
debug "NOT_BACKUP_BEFORE_DELETE: $NOT_BACKUP_BEFORE_DELETE"
debug "--------------------------------- calculated variables"
debug "dir_cfg:------------ $dir_cfg"
debug "config_file:-------- $config_file"
debug "confgi_file_render:- $config_file_render"

debug "hooks_file:--------- $hooks_file"
debug "hook_afterstart:---- $hook_afterstart"
debug "hook_beforestart:--- $hook_beforestart"
debug "script_start:------- $script_start"
debug "action:------------- $action"
debug "where_copy:--------- $where_copy"
debug "use_name:----------- $use_name"
debug "script_backup:------ ${dir_cfg}/${DEF_SCRIPT_BACKUP}"
debug "--------------------------------- VARS files for source"
debug "global_vars:-------- ${global_vars}"
debug "project_vars:------- ${project_vars}"
debug "arg_vars:----------- ${arg_vars}"
debug "project_vault:------ ${project_vault}"
debug "arg_vault:---------- ${arg_vault}"
debug "size array_env:----- ${#array_env[@]}"
for t in ${array_env[@]}; do
  debug "array_env[]:-------- ${t}"
  #eval $t
done
debug "lxc_cmd:------------ ${lxc_cmd}"

debug "NET_INSTANCE:----- ${NET_INSTANCE}"
debug "--------------------------------- argumentes"

### рендеринг $config_file
template_render "$config_file" > "$config_file_render"

### выход, не выполняя никаких фактичеких действий с LXD
[ $DEBUG_LEVEL -ge 100 ] && exit 0

### НАЧАЛО РАБОТЫ С lxc container

case "$action" in
  'add')    {
      debug "Action: add container"
      source ./functions/add.sh
      add_instance
    }
    ;;
  'delete') {
      debug "Action: delete container"
      source ./functions/delete.sh
      delete_instance
    }
    ;;
  'backup') {
      debug "Action: backup data container"
      source ./functions/backup.sh
      backup_data_instance
    }
    ;;
  'export') {
      debug "Action: export container"
      source ./functions/export.sh
      export_instance
    }
    ;;
  else )    {
      echo "Action: UNDEFINED"
    }
    ;;
esac

[[ "$DEBUG" -eq "0" ]] && on_error

echo -e "\nContainer alias: ${CONTAINER_NAME}"
echo "${CONTAINER_NAME}"

