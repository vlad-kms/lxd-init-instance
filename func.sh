#!/bin/bash

source ./functions/common.sh

#source hook.sh

### NOT USE
confgi_yaml_render() {
  echo "123"
}

### NOT USE
add2array_env(){
  echo $array_env
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
  #hook_dispath "export"
  #hook_dispath hooks "export"


}

#test_func_sh
