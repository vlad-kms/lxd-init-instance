#!/bin/bash

help() {
  echo "Help =============================================="
}

debug() {
  if [ "$DEBUG" = "1" ]; then
    echo "deb::: $1"
  fi
}

template_render() {
  eval "echo \"$(cat $1)\""  
}

confgi_yaml_render() {
  echo "123"
}

restart_instance() {
  debug "=== restarting instance"
  lxc stop $CONTAINER_NAME
  lxc start $CONTAINER_NAME
}

add2array_env(){
  echo $array_env
}


create_container() {
# $1 --- $IMAGE_NAME
# $2 --- ${config_file_render}
  if [[ -z $1 ]]; then
    exit 110
  fi
  if [[ -z $2 ]]; then
    lxc init ${1}        | sed -ne 's/Instance name is:[[:blank:]]*\([[:graph:]]*\)$/\1/p'
  else
    lxc init ${1} < ${2} | sed -ne 's/Instance name is:[[:blank:]]*\([[:graph:]]*\)$/\1/p'
  fi
}
