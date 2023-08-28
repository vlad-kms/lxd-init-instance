# Коды возврата
ERR_SHELL=1;                            # ошибка выполнения команд оболочки
ERR_UNDEFINED=99                        # неизвестная ошибка
ERR_BAD_ARG=100;                        # Неверный аргумент: каталог с конфигурационными файлами
ERR_BAD_ARG_FILE_VARS_NOT=101;          # Неверный аргумент: файл с переменными
ERR_BAD_ARG_FILE_SECRET_VARS_NOT=102;   # Неверный аргумент: файл с секретными переменными
ERR_RENDER_TEMPLATE_NOT_CATALOG=103;    # Место для складывания для обработаных шаблонов не является каталогом
ERR_FILE_CONFIG_NOT=104;                # Ошибка открытия файла конфигурации контейнера или он не существует
ERR_BAD_ARG_NOT_CONATINER_NAME=105;     # Неверный аргумент: не передано имя контейнера
ERR_IMAGE_NOT=110;                      # Ошибка передачи имени образа Linux
ERR_CREATE_CONTAINER=120;               # Ошибка при создании контейнера
ERR_BAD_ACTION_LASTCHAR_DIR=125;        # Неверное действия с последним символом в имени каталога
ERR_NOT_SCRIPT_BACKUP=200;              # В каталоге конфигурации нет скрипта для бэкапа ${dir_cfg}/${DEF_SCRIPT_BACKUP}
ERR_NOT_DIR_WHERE_COPY=201;             # Указанное место для фалов бэкапа не является каталогом ${where_copy}

ERR_DELETE_CONTAINER=140                # Ошибка при удалениии контейнера

declare -A msg_arr
msg_arr[${ERR_UNDEFINED}]='Неизвестная ошибка'
msg_arr[${ERR_BAD_ARG}]='Неверные аргументы: неверно указан каталог \"${CONFIG_DIR_NAME}\" с конфигурацией для инициализации экземпляра контейнера или он не существует'
msg_arr[${ERR_BAD_ARG_FILE_VARS_NOT}]='Неверные аргументы: неверно указан файл с переменными \"${VARS_NAME}\"'
msg_arr[${ERR_BAD_ARG_FILE_SECRET_VARS_NOT}]='Неверные аргументы: неверно указан файл с секретными переменными \"${arg_vault}\"'
msg_arr[${ERR_RENDER_TEMPLATE_NOT_CATALOG}]='Неверные аргументы: каталог для подготовленных шаблонов \"$dtr\" не является каталогом'
msg_arr[${ERR_FILE_CONFIG_NOT}]='Файл ${dir_cfg}/${DEF_CFG_YAML} не существует. Выполнение скрипта прервано'
msg_arr[${ERR_BAD_ARG_NOT_CONATINER_NAME}]='Неверные аргументы: требуется имя контейнера для действия'
msg_arr[${ERR_IMAGE_NOT}]='Неверный image'
msg_arr[${ERR_CREATE_CONTAINER}]='Ошибка создания контейнера'
msg_arr[${ERR_NOT_SCRIPT_BACKUP}]='В каталоге конфигурации нет скрипта для бэкапа "${dir_cfg}/${DEF_SCRIPT_BACKUP}"'
msg_arr[${ERR_NOT_DIR_WHERE_COPY}]='Место куда складывать бэкапы не является каталогом "${where_copy}"'
msg_arr[${ERR_BAD_ACTION_LASTCHAR_DIR}]='Неверное действие ${act} с последним символом в имени каталога'
msg_arr[${ERR_DELETE_CONTAINER=140}]='Ошибка при удалениии контейнера ${CONTAINER_NAME}'

lxc_cmd=lxc

DEBUG=0
DEBUG_LEVEL=1

DEF_VARS_CONF=vars.conf
DEF_VARS_VAULT=vars.vault

DEF_FILES=files
DEF_FILES_TMPL=files_tmpl
DEF_FILES_TMPL_RENDER=files_tmpl_render

DEF_DIR_CONFIGS=instances

DEF_GENERAL_CONFIG_DIR=general
DEF_CFG_YAML=cfg.yaml
POSTFIX_CFG_YAML_RENDER=""
POSTFIX_CFG_YAML_RENDER=_render

DEF_HOOK_AFTERSTART=hook_afterstart.sh
DEF_HOOK_BEFORESTART=hook_beforestart.sh
DEF_HOOK_AFTERDELETE=hook_afterdelete.sh
DEF_HOOK_BEFOREDELETE=hook_beforedelete.sh
DEF_HOOKS_FILE='hooks'

DEF_FIRST_SH=first.sh
DEF_SCRIPT_BACKUP=backup.sh
DEF_WHERE_COPY=backup

NOT_BACKUP_BEFORE_DELETE=0

use_name=1
use_dir_cfg=0

### имя файла с функциями-ловушками. При начальной обработке имя преобразуется в '_${hooks_file}.sh'
### по-умолчанию - $DEF_HOOKS_FILE. Переопределять в локальном для инстанса файле vars.conf
#hooks_file='hooks'

item_msg_err() {
  [[ -z $1 ]] && i=$ERR_UNDEFINED || i=$1
  eval echo ${msg_arr[${i}]}
}
