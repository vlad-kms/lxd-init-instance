#!/bin/bash

source ./functions/common.sh

source hook.sh

### NOT USE
confgi_yaml_render() {
  echo "123"
}

### NOT USE
add2array_env(){
  echo $array_env
}

# $1 --- имя контейнера или имя каталога. Как имя контейнера может содержать ':'.
#        поэтому будет вырезано имя каталога, все что после ':'
# Возврат $1 (DEF_DIR_CONFIGS/$1), если он существет и является каталогом. Иначе возврат ''
find_dir_in_location() {
  tdc=${1}
  ### убрать из имени каталога имя сервера, если имя контейнера было как server:container
  #[[ "${tdc}" =~ ":" ]] && tdc=$(echo ${tdc} | sed -n -e  's/\(.*\):\(.*\)/\2/p')
  [[ "${tdc}" =~ ":" ]] && tdc=$(get_part_from_container_name $tdc)
  # вернуть имя каталога, если он существует в ./
  if ([[ -n "$tdc" ]] && [[ -d "$tdc" ]]); then
    echo $tdc
  else
    tdc=${DEF_DIR_CONFIGS}/${tdc}
    # вернуть имя каталога, если он существует в DEF_DIR_CONFIGS, иначе вернуть ''
    ([[ -n "$tdc" ]] && [[ -d "$tdc" ]]) && echo $tdc || echo ''
  fi
}

########################################
# Проверить существование функции
# Вход:
#     $1  - имя функции для проверки
# Выход:
#     return 0    - если не существует
#     echo "not"
#     return 1    - если существует
#     echo "exist"
########################################
is_exists_func() {
  if [[ -z $1 ]]; then
    echo "not"
    return 0
  fi
  declare -F ${1} > /dev/null && {
    echo "exists"
    return 1
  }
  echo "no"
  return 0
}

last_char_dir() {
  [[ -z $1 ]] && {
    return
  }
  s=${1}
  l=${#s}
  act=$2; act=${act:='add'}
  ( [[ "${act}" == "add" ]] || [[ "${act}" == "del" ]] || [[ "${act}" == "get" ]] ) || act='add'
  case "$act" in
    add)
      [[ "${s: -1}" != "/" ]] && s="${s}/"
      ;;
    del)
      [[ "${s: -1}" == "/" ]] && s="${s:0:$((l - 1))}"
      ;;
    get)
      echo "${s: -1}"
      ;;
    *) break_script ${ERR_BAD_ACTION_LASTCHAR_DIR} ;;
  esac
  echo "${s}"
}

test_func_sh(){
  #echo $(get_part_from_container_name 'hhh:ccc' 'h')
  #echo $(get_part_from_container_name 'hhh:ccc')

  #last_char_dir
  #last_char_dir dir/1
  #last_char_dir dir/1 add
  #last_char_dir dir/1/
  #last_char_dir dir/1/ add
  #echo '================='
  #last_char_dir dir/1 del
  #last_char_dir dir/1/ del
  
  #last_char_dir dir/1 get
  #last_char_dir dir/1/ get

  #state_instance lxd-dev:tst2
  #state_instance lxd-dev:tst3
  #state_instance lxd-dev:tst4

  #t=$(is_running_instance lxd-dev:tst2)
  #[[ "$t" == "1" ]] && echo RUNNING || echo HZ
  #[[ $(is_running_instance lxd-dev:tst3) == "1" ]] && echo RUNNING || echo HZ
  #[[ $(is_running_instance lxd-dev:tst4) == "1" ]] && echo RUNNING || echo HZ

  CONTAINER_NAME=/lxd-dev:tst3
  DEBUG_LEVEL=90
  DEBUG=0
  DEF_HOOKS_FILE=hooks
  #export_instance

  #echo $(is_exists_func test_func_sh)
  #ret=$?
  #echo $ret
  #echo $(is_exists_func test_func_sh1)
  #ret=$?
  #echo $ret
  #echo 123 > /dev/null;

  dir_cfg='instances/tst3/'
  hook_dispath "export"
  hook_dispath hooks "export"


}

#test_func_sh
