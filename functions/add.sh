#!/bin/bash

# shellcheck disable=SC1091
source ./functions/hook.sh || source ./hook.sh

########################################
# create container
########################################
create_container() {
# $1 --- $IMAGE_NAME
# $2 --- ${config_file_render}
  if [[ -z $1 ]]; then
    exit 110
  fi
  if [[ -z $2 ]]; then
    # shellcheck disable=SC2154
    $lxc_cmd init "$1" | sed -ne 's/Instance name is:[[:blank:]]*\([[:graph:]]*\)$/\1/p'
  else
    $lxc_cmd init "$1" < "$2" | sed -ne 's/Instance name is:[[:blank:]]*\([[:graph:]]*\)$/\1/p'
  fi
}

########################################
# Инициализация, запуск нового контейнера
########################################
add_instance() {
  before_init_container=${before_init_container:='before_init_container'}
  debug "=== Ловушка перед инициализацией инстанса: $before_init_container"
  # shellcheck disable=SC2154
  hook_dispath "$hooks_file" "${before_init_container}"
  if [[ -n ${config_file} ]]; then
    ### Есть файл config.yaml для инстанса
    if [[ -z $CONTAINER_NAME ]]; then
      ### здесь запуск анонимного инстанса
      # shellcheck disable=SC2154
      debug "--- Запуск анонимного инстанса: ${lxc_cmd} launch ${IMAGE_NAME} < ${config_file_render}. Затем сразу выход"
      #${lxc_cmd} launch ${IMAGE_NAME} < "${config_file_render}"
      CONTAINER_NAME=$(create_container "${IMAGE_NAME}" "${config_file_render}")
    else
      ### Инициализация инстанса
      debug "--- Инит инстанс ${CONTAINER_NAME}: ${lxc_cmd} init ${IMAGE_NAME} ${CONTAINER_NAME} < ${config_file_render}"
      ${lxc_cmd} init "${IMAGE_NAME}" "${CONTAINER_NAME}" < "${config_file_render}" >&2
    fi
  else
    ### нет файла config.yaml для инстанса
    if [[ -z $CONTAINER_NAME ]]; then
      ### здесь запуск анонимного инстанса
      debug "--- Запуск анонимного инстанса: ${lxc_cmd} launch ${IMAGE_NAME} . Затем сразу выход"
      #${lxc_cmd} launch ${IMAGE_NAME}
      CONTAINER_NAME=$(create_container "${IMAGE_NAME}")
    else
      ### Инициализация инстанса
      debug "--- Инит инстанс ${CONTAINER_NAME}: ${lxc_cmd} init ${IMAGE_NAME} ${CONTAINER_NAME}"
      ${lxc_cmd} init "${IMAGE_NAME}" "${CONTAINER_NAME}" >&2
    fi
  fi
  ### Выход если ошибка инициализации инстанса
  ret=$?
  if [[ $ret -ne 0 ]]; then
    exit $ret
  fi
  after_init_container=${after_init_container:='after_init_container'}
  debug "=== Ловушка после инициализации инстанса: $after_init_container"
  hook_dispath "${hooks_file}" "${after_init_container}"
  if [[ -z $CONTAINER_NAME ]]; then
    ### если имя контейнера пусто, то ошибка создания контейнера
    break_script "${ERR_CREATE_CONTAINER}"
  fi

  ### если есть скрипт, который надо выполнить при первом запуске,
  ### то скопировать его в созданный инстансе /run/start/#SCRIPT_NAME
  if [[ -n ${script_start} ]]; then
    ### что-то сделать до запуска контейнера
    dst=/opt/start/script.sh
    debug "--- Копирование скрипта: ${lxc_cmd} file push ${script_start} ${CONTAINER_NAME}${dst}"
    ${lxc_cmd} file push -p --mode 0755 "$script_start" "${CONTAINER_NAME}${dst}"
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
    cd "${dir_cfg}/${DEF_FILES}" || exit 1
    #cd "${dir_cfg}/${DEF_FILES}" || break_script "${}"
    find . -name "*" -type f -print0 | xargs -I {} -r0 "${lxc_cmd}" file push -p {} "${CONTAINER_NAME}/{}"
    ### Выход если ошибка копирования файлов из ${DEF_FILES} в $CONTAINER_NAME/files
    ret=$?
    cd "$op" || exit 1;
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
      break_script "$ERR_RENDER_TEMPLATE_NOT_CATALOG"
    fi
    ### нет каталога, создать его
    [[ ! -d "${dtr}" ]] && mkdir "${dtr}"

    cd "${dir_cfg}/${DEF_FILES_TMPL}" || { echo "Not exists directory \"${dir_cfg}/${DEF_FILES_TMPL}\""; exit 1; }
    tmpfile=$(mktemp)
    find . -name "*" -type f -print | sed 's/^\.\///' > "${tmpfile}"
    ### создать дерево каталогов в подготовленных шаблонах аналогичное в шаблонах
    cp -r --force ./* "${dtr}"
    #cat "${tmpfile}" | while read item
    #do
    #  #debug "--- rendering template item: $item"
    #  template_render "$item" > "${dtr}/$item"
    #done
    while IFS= read -r item
    do
      #debug "--- rendering template item: $item"
      template_render "$item" > "${dtr}/$item"
    done < "${tmpfile}"
    rm "${tmpfile}"
    ### копировать файлы рендерированных шаблонов
    cd "$dtr" ||  { echo "Not exists directory \"${dtr}\""; exit 1; }
    find . -name "*" -type f -print0 | xargs -I {} -r0 "${lxc_cmd}" file push -p {} "${CONTAINER_NAME}/{}"
    ### Выход если ошибка копирования файлов из ${DEF_FILES} в $CONTAINER_NAME/files
    ret=$?
    cd "$op" ||  { echo "Not exists directory \"${op}\""; exit 1; }
    if [[ $ret -ne 0 ]]; then
      exit $ret
    fi
  fi

  ### ловушка перед стартом инстанса
  hook_beforestart=${hook_beforestart:=$DEF_HOOK_BEFORESTART}
  debug "=== Ловушка перед запуском инстанс: $hook_beforestart"
  hook_dispath "${hooks_file}" "${hook_beforestart}"
  #if [[ -n ${hook_beforestart} ]]; then
  #  source ${hook_beforestart}
  #fi
  ### Выход если ошибка при выполнении скрипта-ловушки перед запуском инстанса
  ret=$?
  if [[ $ret -ne 0 ]]; then
    debug "=== Ошибка после запуска скрипта-ловушки ПередЗапуском"
    exit $ret
  fi

  ### СТАРТ
  debug "--- Старт инстанс $CONTAINER_NAME"
  ${lxc_cmd} start "$CONTAINER_NAME"
  ### Выход если ошибка запуска инстанса $CONTAINER_NAME
  ret=$?
  if [[ $ret -ne 0 ]]; then
    exit $ret
  fi

  ### Если существует cloud-init, то ожидать пока cloud-init завершит работу (статус == done)
  if [[ ${DEBUG} -eq 0 ]]; then
    # shellcheck disable=SC2034
    ss=$(${lxc_cmd} exec "${CONTAINER_NAME}" -- sh -c "[ -x /usr/bin/cloud-init ] && cloud-init status --wait")
  else
    ${lxc_cmd} exec "${CONTAINER_NAME}" -- sh -c "[ -x /usr/bin/cloud-init ] && cloud-init status --wait" >&2
    #lxc exec "${CONTAINER_NAME}" -- sh -c "[ -x /usr/bin/cloud-init ] && cloud-init status --wait"
  fi
  #${lxc_cmd} exec "${CONTAINER_NAME}"" -- sh -c "[ -x /usr/bin/cloud-init ] && cloud-init status --wait"

  ### ловушка после старта инстанса и завершения работы cloud-init
  hook_afterstart=${hook_afterstart:=$DEF_HOOK_AFTERSTART}
  debug "=== Ловушка после запуска инстанс: $hook_afterstart"
  hook_dispath "${hooks_file}" "${hook_afterstart}"
  #if [[ -n ${hook_afterstart} ]]; then
  #  debug "=== Ловушка после запуска инстанс: $hook_afterstart"
  #  source "${hook_afterstart}"
  #fi
  ### Выход если ошибка при выполнении скрипта-ловушки после запуском инстанса
  ret=$?
  if [[ $ret -ne 0 ]]; then
    exit $ret
  fi

  ### скрипт после запуска инстанса, выполняемый внутри контейнера
  if [[ -n ${script_start} ]]; then
    debug "=== Скрипт после запуска инстанс, выполняемый в контейнере: ${SCRIPT_NAME} ---> ${dst}"
    ${lxc_cmd} exec "$CONTAINER_NAME" -- bash -c ". ${dst}"
  fi

  ### если требуется перезапуск, то выполнить его
  [ "$AUTO_RESTART_FINAL" -ne "0" ] && restart_instance "${CONTAINER_NAME}"
}
