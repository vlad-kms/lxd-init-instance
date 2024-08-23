#!/bin/bash

# shellcheck disable=SC1091
source ./functions/hook.sh || source hook.sh

delete_instance() {
### Удаление контейнера
  ### делаем backup контейнера, если $NOT_BACKUP_BEFORE_DELETE ==0
  ret_code=0
  if [ "$NOT_BACKUP_BEFORE_DELETE" -eq "0" ]; then
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
  # shellcheck disable=SC2016
  debug '--- source ${dir_cfg}/${DEF_HOOK_BEFOREDELETE}'
  debug "--- source ${dir_cfg}/${DEF_HOOK_BEFOREDELETE}"
  if [[ -n ${dir_cfg} ]] && [[ -d ${dir_cfg} ]] && [[ -f ${dir_cfg}/${DEF_HOOK_BEFOREDELETE} ]]; then
    source ${dir_cfg}/${DEF_HOOK_BEFOREDELETE}
  fi
  if [ $ret_code -eq 0 ]; then
    debug "ret_code: $ret_code"
    debug "--- $lxc_cmd delete --force ${CONTAINER_NAME}"
    [ $DEBUG_LEVEL -lt 90 ] && $lxc_cmd delete --force "${CONTAINER_NAME}"
    [[ $? -ne 0 ]] && break_script $ERR_DELETE_CONTAINER
  elif [ $ret_code -eq 1 ]; then
    debug "ret_code: $ret_code"
    debug "--- $lxc_cmd delete --force ${CONTAINER_NAME}"
    [[ $DEBUG_LEVEL -lt 90 ]] && $lxc_cmd delete --force ${CONTAINER_NAME}
    [[ $? -ne 0 ]] && break_script $ERR_DELETE_CONTAINER
    ret_code=0
    return
  elif [ $ret_code -eq 2 ]; then
    debug "ret_code: $ret_code"
  else
    debug "ret_code: $ret_code"
    return
  fi
  [[ -z ${ret_message} ]] || echo "${ret_message}"

    # ловушка после удаления контейнера
  # shellcheck disable=SC2016
  debug '--- source ${dir_cfg}/${DEF_HOOK_AFTERDELETE}'
  debug "--- source ${dir_cfg}/${DEF_HOOK_AFTERDELETE}"
  if [[ -n ${dir_cfg} ]] && [[ -d ${dir_cfg} ]] && [[ -f ${dir_cfg}/${DEF_HOOK_AFTERDELETE} ]]; then
    source ${dir_cfg}/${DEF_HOOK_AFTERDELETE}
  fi
}
