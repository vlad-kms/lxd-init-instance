#!/bin/sh

after_init_container() {
  debug "DISPATH HOOK: after_init_container"
}

after_start() {
  debug "DISPATH HOOK: Run ${0}:hook-afterstart::after_start"
  # shellcheck disable=SC2154
  debug "lxc_cmd: ${lxc_cmd}"
  cmd="${lxc_cmd} exec ${CONTAINER_NAME} -- "

  # очистить кэш
  ${cmd} apt-get clean
}
