#!/bin/bash

trap clear_working EXIT
#trap on_error ERR

# подключение функций и глобальных переменных
source ./functions/global_vars.sh
source ./functions/common.sh
source ./functions/cipher.sh

#source ./functions/hook.sh

#source func-tm.sh

#unset SCRIPT_NAME

#############################################
# обработка ошибок
#############################################
clear_working() {
  { [[ -n "${tmpfile}" ]]  && [[ -f "${tmpfile}" ]]; }  && rm "${tmpfile}"
  { [[ -n "${tmpfile1}" ]] && [[ -f "${tmpfile1}" ]]; } && rm "${tmpfile1}"
  { [[ -n "${dtr}" ]] && [[ -d "${dtr}" ]]; } && rm -r "${dtr}"
}

on_error() {
  clear_working
  exit 1
}

#############################################
# 
#############################################
set_action() {
  if [[ -z $1 ]]; then
    return 0
  fi
  if [[ -n $action ]]; then
    help
    break_script "$ERR_BAD_ARG_COMMON" " Не может быть задано два действия в одном запуске (1-е) ${1}; (2-е) ${action}"
  fi
  action="$1"
}

####################################################################################
# СКРИПТ
####################################################################################

declare -a array_env
# массив всех доступных action
actions=(add backup dec_file delete enc_file export)


# новый разбор аргументов. Теперь если первый аргумент не начинается с '-', то это action, осталное опции для action
# action: add, backup, delete, decode-file, encode-file, export
#args=$@
if ! _startswith "$1" '-'; then
  # здесь 1-й аргумент не начинается с '-', т.е. здесь первый аргумент, все остальное опции
  action="$1"
  shift
else
  action=''
fi

#args=$(getopt -u -o 'a:bc:de:hi:nt:p:u:v:w:x' --long 'add,alias:,backup,config-dir:,cipher-file-dir:,cipher-file-name:,encode-file,decode-file,debug,delete,env:,help,image:,not-backup,pass-file:,timeout:,vaults:,vars:,where-copy:,debug-level:,use-name:,use_dir_cfg:,export' -- "$@")
if ! args=$(getopt -u -o 'a:bc:de:hi:nt:p:u:v:w:x' --long 'add,alias:,backup,config-dir:,cipher-file-dir:,cipher-file-name:,encode-file,decode-file,debug,delete,env:,help,image:,not-backup,pass-file:,timeout:,vaults:,vars:,where-copy:,debug-level:,use-name:,use-dir-cfg:,export' -- "$@"); then
  help;
  exit 1
fi

# shellcheck disable=SC2086
set -- $args
debug "$args"
i=0
for i; do
    case "$i" in
        '--add')
            set_action 'add';
            shift;;
        '-a' | '--alias')       CONTAINER_NAME=${2};  shift 2;;
        '-b' | '--backup')
            set_action 'backup'
            shift;;
        '-c' | '--config-dir')  CONFIG_DIR_NAME=${2}; shift 2;;
        '--cipher-file-dir')    cipher_file_dir=${2}; shift 2;;
        '--cipher-file-name')   cipher_file_name=${2};shift 2;;
        '-d' | '--delete')      action="delete";      shift;;
        '--debug')              DEBUG=1;              shift;;
        '--debug-level')        DEBUG_LEVEL=$2;       shift 2;;
        '--decode-file')
            set_action 'dec_file'
            shift;;
        '--encode-file')
            set_action 'enc_file'
            shift;;
        '-e' | '--env')         array_env+=( "$2" );    shift 2;;
        '-h' | '--help')        help; exit 0          ;;
        '-i' | '--image')       arg_image_name=${2};  shift 2;;
        '-n' | '--not-backup')  NOT_BACKUP_BEFORE_DELETE=1; shift;;
        '-p' | '--pass_file')   pass_file="${2}";     shift 2;; 
        '-t' | '--timeout')     TIMEOUT=${2};         shift 2;;
        '-u' | '--vaults')      VAULTS_NAME=${2};     shift 2;;
        '-v' | '--vars')        VARS_NAME=${2};       shift 2;;
        '-w' | '--where-copy')  arg_where_copy=${2};  shift 2;;
        '--use-name')           use_name=${2};        shift 2;;
        '--use-dir-cfg')        use_dir_cfg=${2};     shift 2;;
        '-x' | '--export')
            set_action 'export'
            shift;;
        else)
            item_msg_err "$ERR_BAD_ARG_COMMON"; echo " $i"
            help;
            exit 0
            ;;
    esac
done

### --timeout, по-умолчанию = 60 сек
TIMEOUT=${TIMEOUT:=60}
### Если action не передан, то по-умолчанию add
action=${action:="add"}
# TODO проверить action на валидность
is_valid=0
for value in "${actions[@]}"
do
  if [[ "$action" = "$value" ]]; then
    is_valid=1
    break
  fi
done
if (( is_valid != 1)); then
  break_script "$ERR_BAD_ARG_COMMON" " Неверно указано действие ${action}"
fi

### --pass_file (-p) начальная инициализация cipher шифрования
#init_cipher $pass_file
init_cipher
cipher_file_dir=${cipher_file_dir:=${DEF_CIPHER_FILE_DIR}}
cipher_file_name=${cipher_file_name:=${DEF_CIPHER_FILE_NAME}}

### Подготовка командной строки в зависимости от ключа --debug
if [ "${DEBUG}" -eq 0 ]; then
  lxc_cmd="${lxc_cmd} -q"
else
  if [ "$DEBUG_LEVEL" -eq "1" ]; then
    # shellcheck disable=SC2269
    lxc_cmd="${lxc_cmd}"
  elif [ "${DEBUG_LEVEL}" -eq "2" ]; then
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
  [[ -n $dir_cfg ]] && dir_cfg=$(find_dir_in_location "$dir_cfg")
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
if ! { [[ -n "$dir_cfg" ]] && [[ -d "$dir_cfg" ]]; }; then
  break_script ${ERR_BAD_ARG}
fi

### Подгружаем переменные
### Сначала из файла ИМЯСКРИПТА.conf
global_vars=${0}.conf
# shellcheck source=functions/${global_vars}
# shellcheck disable=SC1091
[[ -f "${global_vars}" ]] && source "${global_vars}"
### Теперь подгружаем переменные из каталога с конфигурацией инстанса
### ${dir_cfg}/${DEF_VARS_CONF} (vars.conf)
project_vars="${dir_cfg}/${DEF_VARS_CONF}"
# shellcheck source=functions/${project_vars}
if [[ -f ${project_vars} ]]; then
  # shellcheck disable=SC2086
  # shellcheck disable=SC1091
  source ${project_vars}
else
  project_vars
fi
### Если передали -v (--vars), то подгружаем переменные из файла переданного в этом параметре
arg_vars="${VARS_NAME}"
### Проверить что $arg_vars является файлом, если передан как аргумент
### Если не файл,но передан в аргументе, то ошибка и прервать скрипт
if { [[ -n "$arg_vars" ]] && [[ ! -f "$arg_vars" ]]; }; then
  break_script ${ERR_BAD_ARG_FILE_VARS_NOT} ". Аргумент -v (--vars) ${arg_vars}"
fi
# shellcheck source=functions/${arg_vars}
if [[ -f ${arg_vars} ]]; then
  # shellcheck disable=SC1091
  # shellcheck disable=SC2086
  source ${arg_vars}
else
  unset arg_vars
fi

### Теперь подгружаем секретные переменные из каталога с конфигурацией инстанса
### ${dir_cfg}/${DEF_VARS_VAULT} (vars.vault)
project_vault="${dir_cfg}/${DEF_VARS_VAULT}"
# shellcheck source=functions/${project_vault}
if [[ -f ${project_vault} ]]; then
  # shellcheck disable=SC1091
  # shellcheck disable=SC2086
  source ${project_vault}
else
  unset project_vault
fi
arg_vault="${VAULTS_NAME}"
### Проверить что $arg_vault является файлом, если передан как аргумент
### Если не файл, но передан в аргументе, то ошибка и прервать скрипт
if { [[ -n "$arg_vault" ]] && [[ ! -f "$arg_vault" ]]; }; then
  break_script ${ERR_BAD_ARG_FILE_SECRET_VARS_NOT} ". Аргумент -u (--vaults) ${arg_vault}"
fi
# shellcheck source=functions/${arg_vault}
if [[ -f ${arg_vault} ]]; then
  # shellcheck disable=SC1091
  # shellcheck disable=SC2086
  source ${arg_vault}
else
  unset arg_vault
fi

### Теперь заменяем переменные, значениями переданными через командную строку (-e, --env)
for t in "${array_env[@]}"; do
  eval "$t"
done

### Инициализация имени образа. Аргумент --image (-i) заменяет имя образа из файлов переменных
[[ -n "$arg_image_name" ]] && IMAGE_NAME=${arg_image_name}

### инитиализация имен файлов конфига, скриптов презапуска, запуска, послезапуска для контейнера
### файл конфигурации
#$(last_char_dir ${dir_cfg})
config_file="$(last_char_dir "${dir_cfg}")${DEF_CFG_YAML}"
### если файла нет, то очистить переменную. Нет конфига
[[ -f ${config_file} ]] || unset config_file
### если файл cfg есть, то инит confgi_file_render,
### иначе очистить confgi_file_render
if [[ -f ${config_file} ]]; then
  config_file_render="${config_file}${POSTFIX_CFG_YAML_RENDER}"
else
  unset config_file_render
fi
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
if [[ $use_dir_cfg -ne 0 ]]; then
  pref="${dir_cfg}/"
else
  pref=""
fi
where_copy=${where_copy:=${pref}${DEF_WHERE_COPY}}
[[ -n $arg_where_copy ]] && where_copy=${arg_where_copy}
# последний символ не д.б. '/'
where_copy=$(last_char_dir "${where_copy}" del)
# добавить имя контейнера к пути бэкапа
if [[ ${use_name} -ne 0 ]]; then
  lxd_host=$(get_part_from_container_name "${CONTAINER_NAME}" h)
  if [[ -z "$lxd_host" ]]; then
    where_copy="${where_copy}/$(get_part_from_container_name "${CONTAINER_NAME}")"
  else
    where_copy="${where_copy}/${lxd_host}-$(get_part_from_container_name "${CONTAINER_NAME}")"
  fi
fi
# последний символ не д.б. '/'
where_copy=$(last_char_dir "${where_copy}" del)
# ошибка, если файл существует и не является каталогом
{ [[  -a $where_copy ]] && [[ ! -d $where_copy ]]; } && break_script $ERR_NOT_DIR_WHERE_COPY
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
debug "action:------------- $action"
debug "dir_cfg:------------ $dir_cfg"
debug "config_file:-------- $config_file"
debug "confgi_file_render:- $config_file_render"
debug "hooks_file:--------- $hooks_file"
debug "hook_afterstart:---- $hook_afterstart"
debug "hook_beforestart:--- $hook_beforestart"
debug "script_start:------- $script_start"
debug "use_dir_cfg:-------- ${use_dir_cfg}"
debug "use_name:----------- ${use_name}"
debug "where_copy:--------- $where_copy"
debug "script_backup:------ ${dir_cfg}/${DEF_SCRIPT_BACKUP}"
debug "--------------------------------- VARS files for source"
debug "global_vars:-------- ${global_vars}"
debug "project_vars:------- ${project_vars}"
debug "arg_vars:----------- ${arg_vars}"
debug "project_vault:------ ${project_vault}"
debug "arg_vault:---------- ${arg_vault}"
debug "size array_env:----- ${#array_env[@]}"
for t in "${array_env[@]}"; do
  debug "array_env[]:-------- ${t}"
  #eval $t
done
debug "lxc_cmd:------------ ${lxc_cmd}"

debug "NET_INSTANCE:----- ${NET_INSTANCE}"
debug "--------------------------------- argumentes"

### рендеринг $config_file
template_render "$config_file" > "$config_file_render"

### выход, не выполняя никаких фактичеких действий с LXD
[[ $DEBUG_LEVEL -ge 100 ]] && exit 0

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
  'dec_file') {
      echo "Action: dec_file"
      if [[ "${cipher_file_name}" == "${DEF_CIPHER_FILE_NAME}" ]]; then
        cipher_file_name="${cipher_file_name}-enc"
      fi
      arr_files=$(find "${cipher_file_dir}" -type f -name "${cipher_file_name}")
      for item in "${arr_files[@]}"; do
        decode_file "${item}" "${item::-4}";
        debug "$item"
      done
    }
    ;;
  'enc_file') {
      echo "Action: enc_file"
      arr_files=$(find "${cipher_file_dir}" -type f -name "${cipher_file_name}")
      for item in "${arr_files[@]}"; do
        encode_file "${item}" "${item}-enc";
        debug "$item"
      done
    }
    ;;
  else )    {
      echo "Action: UNDEFINED"
    }
    ;;
esac

echo -e "\nContainer alias: ${CONTAINER_NAME}"
echo "${CONTAINER_NAME}"

#[[ "$DEBUG" -eq "0" ]] && clear_working
