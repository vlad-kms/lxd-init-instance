#!/bin/bash

#####################################################
# Экспорт контейнера
#####################################################
export_instance() {
  debug "Экспорт контейнера ${CONTAINER_NAME}"
  is_running=$(is_running_instance ${CONTAINER_NAME})
  archive_name="$(get_part_from_container_name ${CONTAINER_NAME} h)-$(get_part_from_container_name ${CONTAINER_NAME})-image-container.tar.gz"
  debug "archive_name: ${archive_name}"
  # ловушка перед lxc stop и lxc export
  hook_before_export=${hook_before_export:='before_export'}
  hook_dispath "${hooks_file}" "${hook_before_export}"

  [[ $DEBUG_LEVEL -lt 90 ]] && [[ $is_running -eq 1 ]] && $lxc_cmd stop ${CONTAINER_NAME}
  [[ $DEBUG_LEVEL -lt 90 ]] && $lxc_cmd export ${CONTAINER_NAME} ${archive_name}
  [[ -e ${where_copy} ]] || mkdir -p ${where_copy}
  mv -f -t ${where_copy} ${archive_name}
  [[ $DEBUG_LEVEL -lt 90 ]] && [[ $is_running -eq 1 ]] && $lxc_cmd start ${CONTAINER_NAME}
  # ловушка после lxc export и lxc start
  hook_after_export=${hook_after_export:='after_export'}
  hook_dispath "${hooks_file}" "${hook_after_export}"
}

