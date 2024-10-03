#!/bin/bash

# shellcheck disable=SC1091
source ./functions/global_vars.sh
#source ./functions/common.sh

# Используется шифрование и какой провайдер:
#   =0, шифрование не используется, и не нашли openssl и gpg
#   =1, шифрование используется, провайдер openssl
#   =2, шифрование используется, провайдер gpg - НЕ РАБОТАЕТ, не используется
#   другое, шифрование не используется
USE_CIPHER=0
DEF_CIPHER_PASSWORD_DIR="./secrets"
DEF_CIPHER_PASSWORD_FILE="cipher_pass"

not_provider() {
    USE_CIPHER=0
    CIPHER_CMD=''
    CIPHER_ALGO=''
    CIPHER_SALT=''
    # shellcheck disable=SC2034
    CIPHER_CMD_ENCODE=''
    # shellcheck disable=SC2034
    CIPHER_CMD_DECODE=''
    CIPHER_BASE64=''
    CIPHER_PBKDF2=''
    a=$(sed -n -e '/secrets/p' "$gitig")
    if [[ -f "$gitig" ]] && [[ -z $a ]]; then
        echo >> "$gitig"
        echo "**secrets" >> "$gitig"
    fi
}

############################################################
# начальная подготовка к работе с шифрованием
############################################################
init_cipher() {
    local gitig='.gitignore'
    file_pass=${file_pass:=${DEF_CIPHER_PASSWORD_DIR}/${DEF_CIPHER_PASSWORD_FILE}}
    [[ -f $file_pass ]] || file_pass=${DEF_CIPHER_PASSWORD_DIR}/${file_pass}
    [[ -f $file_pass ]] || file_pass=${DEF_CIPHER_PASSWORD_DIR}/${DEF_CIPHER_PASSWORD_FILE}
    [[ -f $file_pass ]] || {
        echo "Нет файла пароля" 1>&2
        not_provider
        return 0
    }
    if [[ -x /bin/openssl ]]; then
        # провайдер openssl
        USE_CIPHER=1
        CIPHER_CMD='openssl enc'
        CIPHER_ALGO='-camellia256'
        CIPHER_SALT='-salt'
        CIPHER_ENCODE='-e'
        CIPHER_DECODE='-d'
        CIPHER_BASE64='-base64'
        CIPHER_PBKDF2='-pbkdf2'
        [[ -f $file_pass ]] || 
        #CIPHER_CMD
        debug "file_pass: $file_pass"
    #elif [[ -x /bin/gpg ]]; then
    #    # провайдер gpg
    #    USE_CIPHER=0
    #    CIPHER_CMD=''
    #    CIPHER_ALGO=''
    #    CIPHER_SALT=''
    #    CIPHER_CMD_ENCODE=''
    #    CIPHER_CMD_DECODE=''
    else
        echo "Не установлен пакет openssl. Поэтому шифрование не будет использоваться" 1>&2
        not_provider
    fi
    return 0
}

##################################################
# Зашифровать строку
# Вход:
#   $1  - строка для шифрования
#   $2  - пароль. Если пустая, то взять пароль из первой строки файла $file_pass
# Выход:
##################################################
encode_str() {
    [[ "$USE_CIPHER" == "0" ]] && {
        echo "Не инициализировали библиотеку шифрования, или она не установлена в системе" 1>&2
        return
    }
    [[ -z $1 ]] && {
        echo "Нет строки для шифрования" 1>&2
        return
    }
    if [[ -z $2 ]]; then
        # shellcheck disable=SC2155
        local pw=$(get_password_key)
    else
        local pw=$2
    fi
    enc_str=$(echo "$1" | ${CIPHER_CMD} "${CIPHER_ENCODE}" "${CIPHER_ALGO}" "${CIPHER_SALT}" "${CIPHER_BASE64}" "${CIPHER_PBKDF2}" -k "$pw")
    #enc_str=$(echo $1 | ${CIPHER_CMD} ${CIPHER_ALGO} ${CIPHER_SALT} ${CIPHER_ENCODE} ${CIPHER_BASE64} ${CIPHER_PBKDF2} -kfile $file_pass)
    echo "$enc_str"
}

##################################################
# Расшифровать строку
# Вход:
#   $1  - строка для шифрования
#   $2  - пароль. Если пустая, то взять пароль из первой строки файла $file_pass
# Выход:
##################################################
decode_str() {
    [[ "$USE_CIPHER" == "0" ]] && {
        echo "Не инициализировали библиотеку шифрования, или она не установлена в системе" 1>&2
        return
    }
    [[ -z $1 ]] && {
        echo "Нет строки для расшифрования" 1>&2
        return
    }
    if [[ -z $2 ]]; then
        # shellcheck disable=SC2155
        local pw=$(get_password_key)
    else
        local pw=$2
    fi
    enc_str=$(echo "$1" | ${CIPHER_CMD} "${CIPHER_DECODE}" "${CIPHER_ALGO}" "${CIPHER_SALT}" "${CIPHER_BASE64}" "${CIPHER_PBKDF2}" -k "$pw")
    echo "$enc_str"
}

##################################################
# Зашифровать файл
# Вход:
#   $1  - имя файла для шифрования
#   $2  - имя файла для записи шифрованного текста
#   $3  - пароль. Если пустая, то взять пароль из первой строки файла $file_pass
# Выход:
#   echo encode_string  - зашифрованная строка
##################################################
encode_file() {
    [[ "$USE_CIPHER" == "0" ]] && {
        echo "Не инициализировали библиотеку шифрования, или она не установлена в системе" 1>&2
        return 1
    }
    [[ -f $1 ]] || {
        echo "Нет файла для шифрования" 1>&2
        return 1
    }
    { [[ -e $2 ]] && [[ ! -f $2 ]]; } && {
        echo "Невозможно записать зашифрованный файл" 1>&2
        return 1
    }
    if [[ -z $3 ]]; then
        # shellcheck disable=SC2155
        local pw=$(get_password_key)
    else
        local pw=$2
    fi
    ${CIPHER_CMD} "${CIPHER_ENCODE}" "${CIPHER_ALGO}" "${CIPHER_SALT}" "${CIPHER_BASE64}" "${CIPHER_PBKDF2}" -k "$pw" -in "$1" -out "$2"
}

##################################################
# Расшифровать файл
# Вход:
#   $1  - имя файла для расшифрования
#   $2  - имя файла для записи расшифрованного текста
#   $3  - пароль. Если пустая, то взять пароль из первой строки файла $file_pass
# Выход:
#   echo encode_string  - зашифрованная строка
##################################################
decode_file() {
    [[ "$USE_CIPHER" == "0" ]] && {
        echo "Не инициализировали библиотеку шифрования, или она не установлена в системе" 1>&2
        return 1
    }
    [[ -f $1 ]] || {
        echo "Нет файла для шифрования" 1>&2
        return 1
    }
    { [[ -e $2 ]] && [[ ! -f $2 ]]; } && {
        echo "Невозможно записать зашифрованный файл" 1>&2
        return 1
    }
    if [[ -z $3 ]]; then
        # shellcheck disable=SC2155
        local pw=$(get_password_key)
    else
        local pw=$2
    fi
    ${CIPHER_CMD} "${CIPHER_DECODE}" "${CIPHER_ALGO}" "${CIPHER_SALT}" "${CIPHER_BASE64}" "${CIPHER_PBKDF2}" -k "$pw" -in "$1" -out "$2"
}

##################################################
# Вернуть пароль из файла
##################################################
get_password_key() {
    [[ -f $file_pass ]] || {
        echo "Не указан пароль" 1>&2
        echo ''
        return 0
    }
    #echo $(sed -n '1p' $file_pass)
    sed -n '1p' "$file_pass"
}


#####################################################
#####################################################
test_cipher() {
    source ./functions/global_vars.sh
    source ./functions/common.sh
    # shellcheck disable=SC2034
    DEBUG=1
    file_pass="pw.vault"

    init_cipher
    str="qwerty
line2"
    echo -e "$str"
    echo
    e_s=$(encode_str "$str")
    echo -e "$e_s"
    echo
    d_s=$(decode_str "$e_s")
    echo -e "$d_s"
    fl='test/file_test'
    cat "$fl"
    encode_file "$fl" "${fl}.enc"
    cat "${fl}.enc"
    decode_file "${fl}.enc" "${fl}.enc.dec"
    cat "${fl}.enc.dec"
}
#test_cipher
