#!/bin/bash

hook_dispath() {
  local script_file=''
  local script_dir=$(last_char_dir ${dir_cfg})
  [[ -z ${1} ]] && script_file='' || script_file="${script_dir}_${1}.sh"
  [[ -z ${2} ]] && func='' || func="${2}"
  # если имя скрипта не передано, то выход ret_code=0 $?=0
  [[ -z ${script_file} ]] && {
    ret_code=0
    return 0
  }
  # если не существует файла  $script, файл скрипта - это второй аргумент
  [[ ! -f $script_file ]] && {
    script_file="${script_dir}${func}"
    unset func
  }
  # если опять не существует файла  $script, то выход. Нет скриптов
  [[ ! -f $script_file ]] && {
    ret_code=0
    return 0
  }

  source $script_file
  if [[ -n $func ]]; then
    ### существует ли функция $func и global_$func
    local gl_fn="global_${func}"
    local x=$(is_exists_func "${gl_fn}")
    local is_gl_fn=$?
    [[ $is_gl_fn -eq 1 ]] && $gl_fn
  fi
  return 0
}
