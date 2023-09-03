#!/bin/bash

#source func.sh

#########################################################################
# Диспетчер вызова ловушек
# $1 - строка, имя файла
# $2 - строка, имя функции в файле
# Если передано 0 аргументов, то выход ничего не делая
# Если передан один параметр, то имя файла будет $DEF_HOOKS_FILE, а $1 - имя функции.
# Если передано два параметра, то имя файла будет $1, а $2 - имя функции.
# Если передано >2 параметров, то имя файла будет $1, а $2 - имя функции. Остальные игнорируются
#
# ИмяФайла будет преобразовано в $(last_char_dir ${dir_cfg})ИмяФайла.sh
# Поиск по следующим критериям:
#   1)
#   2)
#   3)
#   4)
#   5)
#########################################################################
hook_dispath() {
  local script_file=''
  local script_dir=$(last_char_dir ${dir_cfg})
  local c=$#;
  if (( $c >= 2 )); then
    script_file="${script_dir}_${1}.sh"
    func="${2}"
  elif (( $c == 1 )); then
    script_file="${script_dir}_${DEF_HOOKS_FILE}.sh"
    func="${1}"
  else
    # аргументов 0
    ret_code=0
    return 0
  fi
  # сохранить ИмяФункции 
  # если не существует файла  $script_file,
  # то проверить второй аргумент как файл скрипта
  func_arg=${func}
  [[ ! -f $script_file ]] && {
    script_file="${script_dir}${func}"
    unset func
  }
  # если опять не существует файла  $script, то выход. Нет скриптов
  [[ ! -f $script_file ]] && {
    ret_code=0
    return 0
  }

  # подключить файл с ловушками, если он передан и существует
  source $script_file

  if [[ -n $func ]]; then
    ### существует ли функция $func и global_$func
    local gl_fn="global_${func}"
    local x=$(is_exists_func "${gl_fn}")
    local is_gl_fn=$?
    [[ $is_gl_fn -eq 1 ]] && $gl_fn
    x=$(is_exists_func "${func}")
    local is_func=$?
    [[ $is_func -eq 1 ]] && $func
  fi
  return 0
}

test_hook() {
  echo "test hook.sh"
}