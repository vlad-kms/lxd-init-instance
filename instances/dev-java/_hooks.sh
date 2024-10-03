#!/bin/sh

after_init_container() {
  echo "DISPATH HOOK: after_init_container" >&2
}

after_start() {
  echo "DISPATH HOOK: Run ${0}:hook-afterstart::after_start" >&2
  echo "lxc_cmd: ${lxc_cmd}" >&2
  cmd="${lxc_cmd} exec ${CONTAINER_NAME} -- "

  # очистить кэш
  ${cmd} apt-get clean
}

