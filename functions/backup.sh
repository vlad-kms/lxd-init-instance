#!/bin/bash

# shellcheck disable=SC1091
#source ./functions/global_vars.sh
# shellcheck disable=SC1091
source ./functions/hook.sh

backup_data_instance() {
  ### делаем backup контейнера
  debug "--- Бэкап данных из контейнера ${CONTAINER_NAME}"
  [[ -z "${CONTAINER_NAME}" ]] && break_script "${ERR_BAD_ARG_NOT_CONATINER_NAME}"
  # shellcheck disable=SC2154
  [[ ! -f "${dir_cfg}/${DEF_SCRIPT_BACKUP}" ]] && break_script "${ERR_NOT_SCRIPT_BACKUP}"
  debug "--- Выполнить ${dir_cfg}/${DEF_SCRIPT_BACKUP}"
  def_name_tar="$(date +"%Y%m%d-%H%M%S")-named.tar.gz"
  debug "--- Имя файла бэкапа: ${def_name_tar}"
  # shellcheck disable=SC1090
  # shellcheck disable=SC2086
  [[ $DEBUG_LEVEL -lt 90 ]] && archive_name=$(source ${dir_cfg}/${DEF_SCRIPT_BACKUP} ${def_name_tar} | sed -En "s/(.*: )(.*)$/\2/p")
  debug "--- Имя файла бэкапа (после работы): ${archive_name}"
  # shellcheck disable=SC2154
  debug "--- ret_code: ${ret_code}"
  # shellcheck disable=SC2154
  debug "--- ret_message: ${ret_message}"
  # после выхода из скрипта $ret_code содержит код ошибки
  # =0        - нет ошибки
  # >0 && <11 - передать код $ret_code дальше вверх про стеку выполнения
  # >10 - прервать выполнение скрипта и вывести сообщения из msg_arr[ret_code] и $ret_message
  # shellcheck disable=SC2086
  [[ $ret_code -ge 11 ]] && break_script ${ret_code} "${ret_message}"
}

