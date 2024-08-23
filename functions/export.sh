#!/bin/bash

# shellcheck disable=SC1091
source ./functions/hook.sh || source hook.sh

#####################################################
# Экспорт контейнера
#####################################################
export_instance() {
  debug "Экспорт контейнера ${CONTAINER_NAME}"
  is_running=$(is_running_instance "${CONTAINER_NAME}")
  debug "is_running: $is_running"
  #archive_name="$(get_part_from_container_name ${CONTAINER_NAME} h)-$(get_part_from_container_name ${CONTAINER_NAME})-image-container.tar.gz"
  lxd_host_name=$(get_part_from_container_name "${CONTAINER_NAME}" h)
  if [[ -z "$lxd_host_name" ]]; then
    archive_name="$(get_part_from_container_name "${CONTAINER_NAME}")-image-container.tar.gz"
  else
    archive_name="${lxd_host_name}-$(get_part_from_container_name "${CONTAINER_NAME}")-image-container.tar.gz"
  fi
  debug "archive_name: ${archive_name}"
  
  # ловушка перед lxc stop и lxc export
  hook_before_export=${hook_before_export:='before_export'}
  debug "hook_before_export: ${hook_before_export}"
  # shellcheck disable=SC2154
  hook_dispath "${hooks_file}" "${hook_before_export}"

  # shellcheck disable=SC2154
  debug "$lxc_cmd export ${CONTAINER_NAME} ${archive_name}"
  # shellcheck disable=SC2154
  debug "mv -f -t ${where_copy} ${archive_name}"
  if [[ $DEBUG_LEVEL -lt 90 ]]; then
    [[ $is_running -eq 1 ]] && $lxc_cmd stop "${CONTAINER_NAME}"
    $lxc_cmd export "${CONTAINER_NAME}" "${archive_name}"
    [[ -e ${where_copy} ]] || mkdir -p "${where_copy}"
    mv -f -t "${where_copy}" "${archive_name}"
    [[ $is_running -eq 1 ]] && $lxc_cmd start "${CONTAINER_NAME}"
  fi

  # ловушка после lxc export и lxc start
  hook_after_export=${hook_after_export:='after_export'}
  hook_dispath "${hooks_file}" "${hook_after_export}"
}
