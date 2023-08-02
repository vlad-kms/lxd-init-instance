#!/bin/bash

# Код возврата
# 1     - ошибка выполнения команд оболочки
# 100   - Неверный аргумент: каталог с конфигурационными файлами
# 101   - Неверный аргумент: файл с переменными
# 102   - Неверный аргумент: файл с секретными переменными
# 103   - Место для складывания для обработаных шаблонов не является каталогом
# 110   - Ошибка передачи имени образа Linux
# 120   - Ошибка при создании контейнера

# подключение функция
source func.sh
source func-tm.sh

DEBUG=0

DEF_GENERAL_CONFIG_DIR=general
DEF_CFG_YAML=cfg.yaml
POSTFIX_CFG_YAML_RENDER=""
POSTFIX_CFG_YAML_RENDER=_render

DEF_HOOK_AFTERSTART=hook_afterstart.sh
DEF_HOOK_BEFORESTART=hook_beforestart.sh

DEF_VARS_CONF=vars.conf
DEF_VARS_VAULT=vars.vault

DEF_FIRST_SH=first.sh

DEF_FILES=files
DEF_FILES_TMPL=files_tmpl
DEF_FILES_TMPL_RENDER=files_tmpl_render

unset SCRIPT_NAME

####################################################################################
####################################################################################
####################################################################################

declare -a array_env

args=$(getopt -u -o 'a:c:de:hi:t:u:v:' --long 'alias:,config-dir:,debug,env:,help,image:,timeout:,vaults:,vars:' -- "$@")
set -- $args
#echo $args
i=0
for i; do
    case "$i" in
        '-a' | '--alias')       CONTAINER_NAME=${2};    shift 2 ;;
        '-c' | '--config-dir')  CONFIG_DIR_NAME=${2};   shift 2 ;;
        '-d' | '--debug')       DEBUG=1;                shift   ;;
        '-e' | '--env')         array_env+=( $2 );      shift 2 ;;
        '-h' | '--help')        help; exit 0;;
        '-i' | '--image')       arg_image_name=${2};    shift 2 ;;
        '-t' | '--timeout')     TIMEOUT=${2};           shift 2 ;;
        '-u' | '--vaults')      VAULTS_NAME=${2};       shift 2 ;;
        '-v' | '--vars')        VARS_NAME=${2};         shift 2 ;;
        else )                  help; exit 0;;
    esac
done

# --timeout, по-умолчанию = 60 сек
TIMEOUT=${TIMEOUT:=60}

### разбор --alias и --config_dir_name
### есть --alias, есть --config_dir_name
### есть --alias, нет  --config_dir_name
### нет  --alias, есть --config_dir_name
###   lxc launch < $CONFIG_DIR_NAME/$DEF_CFG_YAML
### нет  --alias, нет  --config_dir_name
###   lxc launch < $DEF_GENERAL_CONFIG_DIR/$DEF_CFG_YAML
### Т.е. если нет --alias, то выполняется только одна команда lxc launch < cfg_file .
### Запуск контейнера с файлом конфигурации, в котором можно использовать cloud-init, profiles и т.д.
### Если есть --alias, то полностью работает алгоритм, ради которого все это задумывалось

### каталог с конфигурацией == каталогу по-умолчанию
dir_cfg=${DEF_GENERAL_CONFIG_DIR}
### если определен --alias и существует такой каталог в каталоге запуска,
### то каталог с конфигурацией == этому каталогу
([[ -n "${CONTAINER_NAME}" ]] && [[ -d ${CONTAINER_NAME} ]]) && dir_cfg=${CONTAINER_NAME}
### если определен --config-dir, то каталог с конфигурацией == этому каталогу
[[ -n "${CONFIG_DIR_NAME}" ]] && dir_cfg=${CONFIG_DIR_NAME}
### после проверки $dir_cfg - каталог, где надо брать конфигурацию инстанса

### Проверить что $dir_cfg существует и является каталогом
### Если нет, то ошибка и прервать скрипт
res=0
if ! ([[ -n "$dir_cfg" ]] && [[ -d "$dir_cfg" ]]);then
  echo "Неверные аргументы: неверно указан каталог \"${dir_cfg}\" с конфигурацией для инициализации экземпляра контейнера или он не существует";
  exit 100
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
  echo "Неверные аргументы: неверно указан файл с переменными \"${arg_vars}\"";
  exit 101
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
  echo "Неверные аргументы: неверно указан файл с секретными переменными \"${arg_vault}\"";
  exit 101
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
config_file="${dir_cfg}/${DEF_CFG_YAML}"
### если файла нет, то очистить переменную. Нет конфига
[[ -f ${config_file} ]] || unset config_file
### если файл cfg есть, то инит confgi_file_render,
### иначе очистить confgi_file_render
[[ -f ${config_file} ]] && config_file_render="${config_file}${POSTFIX_CFG_YAML_RENDER}" || unset config_file_render

### файл ловушки перед стартом инстанса
hook_beforestart="${dir_cfg}/${DEF_HOOK_BEFORESTART}"
[[ -f ${hook_beforestart} ]] || unset hook_beforestart
### файл ловушки после старта инстанса
hook_afterstart="${dir_cfg}/${DEF_HOOK_AFTERSTART}"
[[ -f ${hook_afterstart} ]] || unset hook_afterstart
### файл скрипта, выполняемого при старте инстанса
script_start="${dir_cfg}/${DEF_FIRST_SH}"
[[ -f ${script_start} ]] || unset script_start

debug "--------------------------------- argumentes"
debug "TIMEOUT:------------ $TIMEOUT"
debug "IMAGE_NAME:--------- $IMAGE_NAME"
debug "CONTAINER_NAME:----- $CONTAINER_NAME"
debug "CONFIG_DIR_NAME:---- $CONFIG_DIR_NAME"
debug "VARS_NAME:---------- $VARS_NAME"
debug "--------------------------------- calculated variables"
debug "dir_cfg:------------ $dir_cfg"
debug "config_file:-------- $config_file"
debug "confgi_file_render:- $config_file_render"

debug "hook_afterstart:---- $hook_afterstart"
debug "hook_beforestart:--- $hook_beforestart"
debug "script_start:------- $script_start"
debug "--------------------------------- VARS files for source"
debug "global_vars:-------- ${global_vars}"
debug "project_vars:------- ${project_vars}"
debug "arg_vars:----------- ${arg_vars}"
debug "project_vault:------ ${project_vault}"
debug "arg_vault:---------- ${arg_vault}"
debug "array_env:---------- ${array_env[@]}"
debug "size array_env:----- ${#array_env[@]}"
for t in ${array_env[@]}; do
  debug "array_env[]:---- ${t}"
  #eval $t
done
debug "NET_INSTANCE:----- ${NET_INSTANCE}"
debug "--------------------------------- argumentes"

#exit

#test_cloud_init_done
#echo "test_cloud_init_done: $?"
#status_cloud_init_tm $TIMEOUT
#echo "status_cloud_init_tm: $?"

### рендеринг $config_file
template_render "$config_file" > "$config_file_render"

### если здесь анонимный инстанс, то запуск через lxc launch.
### Сразу завершение скрипта, пропуская все остальные шаги
if [[ -n ${config_file} ]]; then
  ### если есть файл config.yaml для инстанса
  if [[ -z $CONTAINER_NAME ]]; then
    ### здесь запуск анонимного инстанса
    debug "--- Запуск анонимного инстанса: lxc launch ${IMAGE_NAME} < "${config_file_render}" . Затем сразу выход"
    #lxc launch ${IMAGE_NAME} < "${config_file_render}"
    CONTAINER_NAME=$(create_container ${IMAGE_NAME} ${config_file_render})
  else
    ### Инициализация инстанса
    debug "--- Инит инстанс ${CONTAINER_NAME}: lxc init ${IMAGE_NAME} ${CONTAINER_NAME} < ${config_file_render}"
    lxc init ${IMAGE_NAME} ${CONTAINER_NAME} < "${config_file_render}"
  fi
else
  ### если нет файла config.yaml для инстанса
  if [[ -z $CONTAINER_NAME ]]; then
    ### здесь запуск анонимного инстанса
    debug "--- Запуск анонимного инстанса: lxc launch ${IMAGE_NAME} . Затем сразу выход"
    #lxc launch ${IMAGE_NAME}
    CONTAINER_NAME=$(create_container ${IMAGE_NAME})
  else
    ### Инициализация инстанса
    debug "--- Инит инстанс ${CONTAINER_NAME}: lxc init ${IMAGE_NAME} ${CONTAINER_NAME}"
    lxc init ${IMAGE_NAME} ${CONTAINER_NAME}
  fi
fi
### Выход если ошибка инициализации инстанса
ret=$?
if [[ $ret -ne 0 ]]; then
  exit $ret
fi
if [[ -z $CONTAINER_NAME ]]; then
  ### если имя контейнера пусто, то ошибка создания контейнера
  exit 120
fi

### если есть скрипт, который надо выполнить при первом запуске,
### то скопировать его в созданный инстансе /run/start/#SCRIPT_NAME
if [[ -n ${script_start} ]]; then
  ### что-то сделать до запуска контейнера
  dst=/opt/start/script.sh
  debug "--- Копирование скрипта: lxc file push ${script_start} ${CONTAINER_NAME}${dst}"
  lxc file push -p --mode 0755 $script_start $CONTAINER_NAME$dst
  ### Выход если ошибка копирования скрипта запуска
  ret=$?
  if [[ $ret -ne 0 ]]; then
    exit $ret
  fi
fi

### если есть каталог $DEF_FILES в каталоге с конфигурационными файлами,
### то скопировать из него все файлы (каталоги) в инстанс
if [[ -d "${dir_cfg}/${DEF_FILES}" ]]; then
  debug "--- Работа с файлами"
  op=$(pwd)
  cd "${dir_cfg}/${DEF_FILES}"
  find . -name "*" -type f -print0 | xargs -I {} -r0 lxc file push -p {} "${CONTAINER_NAME}/{}"
  ### Выход если ошибка копирования файлов из ${DEF_FILES} в $CONTAINER_NAME/files
  ret=$?
  cd $op
  if [[ $ret -ne 0 ]]; then
    exit $ret
  fi
fi

### если есть каталог $DEF_FILES_TMPL в каталоге с конфигурационными файлами,
### то скопировать из него все файлы (каталоги) в инстанс, предварительно шаблонизировав
### с помощью eval
#DEF_FILES_TMPL=files_tm папка с шаблонами
#DEF_FILES_TMPL_RENDER=files_tmpl_render папка с рендериными файлами
if [[ -d "${dir_cfg}/${DEF_FILES_TMPL}" ]]; then
  debug "--- Работа с шаблонами"
  op=$(pwd)
  ### имя каталога для рендерованных шаблонов
  dtr="${op}/${dir_cfg}/${DEF_FILES_TMPL_RENDER}"
  debug "--- dtr: $dtr"
  if [[ -f $dtr ]]; then
    ### не является каталогом, ошибка 103
    echo "Неверные аргументы: каталог для подготовленных шаблонов \"$dtr\" не является каталогом";
    exit 103
  fi
  ### нет каталога, создать его
  [[ ! -d "${dtr}" ]] && mkdir "${dtr}"

  cd "${dir_cfg}/${DEF_FILES_TMPL}"
  tmpfile=$(mktemp)
  find . -name "*" -type f -print | sed 's/^\.\///' > "${tmpfile}"
  ### создать дерево каталогов в подготовленных шаблонах аналогичное в шаблонах
  cp -r * ${dtr}
  cat "${tmpfile}" | while read item
  do
    #debug "--- rendering template item: $item"
    template_render $item > "${dtr}/$item"
  done
  rm "${tmpfile}"
  ### копировать файлы рендерированных шаблонов
  cd $dtr
  find . -name "*" -type f -print0 | xargs -I {} -r0 lxc file push -p {} "${CONTAINER_NAME}/{}"
  
  ### Выход если ошибка копирования файлов из ${DEF_FILES} в $CONTAINER_NAME/files
  ret=$?
  cd $op
  if [[ $ret -ne 0 ]]; then
    exit $ret
  fi
fi

### ловушка перед стартом инстанса
if [[ -n ${hook_beforestart} ]]; then
  debug "=== Ловушка перед запуском инстанс: $hook_beforestart"
  source ${hook_beforestart}
fi
### Выход если ошибка при выполнении скрипта-ловушки перед запуском инстанса
ret=$?
if [[ $ret -ne 0 ]]; then
  debug "=== Ошибка после запуска скрипта-ловушки ПередЗапуском"
  exit $ret
fi

### СТАРТ
debug "--- Старт инстанс $CONTAINER_NAME"
lxc start $CONTAINER_NAME
### Выход если ошибка запуска инстанса $CONTAINER_NAME
ret=$?
if [[ $ret -ne 0 ]]; then
  exit $ret
fi

### проверить что cloud-init завершил работу (статус == done)
#lxc exec ${CONTAINER_NAME} -- cloud-init status --wait
lxc exec ${CONTAINER_NAME} -- sh -c "[[ -x /usr/bin/cloud-init ]] && cloud-init status --wait"
# ловушка после старта инстанса и завершенияработы cloud-init
if [[ -n ${hook_afterstart} ]]; then
  debug "=== Ловушка после запуска инстанс: $hook_afterstart"
  source "${hook_afterstart}"
fi
### Выход если ошибка при выполнении скрипта-ловушки после запуском инстанса
ret=$?
if [[ $ret -ne 0 ]]; then
  exit $ret
fi

if [[ -n ${script_start} ]]; then
  debug "=== Скрипт после запуска инстанс, выполняемый в контейнере: ${SCRIPT_NAME} ---> ${dst}"
  sleep 5
  lxc exec $CONTAINER_NAME -- sh -c "source ${dst}"
fi

[ "$AUTO_RESTART_FINAL" -ne 0 ] && restart_instance

echo "Container alias: ${CONTAINER_NAME}"
