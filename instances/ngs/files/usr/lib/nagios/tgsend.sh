#!/bin/bash

#set -o pipefail

scr=$(echo $0 | sed -En "s/.*\/(.*)$/\1/p")
file_log=/var/log/nagios/${scr}.log
[[ ! -f "$file_log" ]] && {
    touch "$file_log"
}
chown nagios:adm "$file_log"
chmod 0640 "$file_log"

STATUS_OK=0;
STATUS_WARNING=1;
STATUS_CRITICAL=2;
STATUS_UNKNOWN=3;
APIURL="https://api.telegram.org/bot${2}/sendMessage"

if [[ -n $6 ]]; then
    echo "1: $1" >> "$file_log"
    echo "2: $2" >> "$file_log"
    echo "3: $3" >> "$file_log"
    echo "4: $4" >> "$file_log"
    echo "5: $5" >> "$file_log"
    echo "6: $6" >> "$file_log"
    echo "7: $7" >> "$file_log"
    echo "8: $8" >> "$file_log"
    echo "_CONTACTEMAIL: $_CONTACTEMAIL$" >> "$file_log"
    echo "NAGIOS_CONTACTEMAIL: $NAGIOS_CONTACTEMAIL" >> "$file_log"
    echo "LOGFILE: $LOGFILE$:123" >> "$file_log"
    echo "NAGIOS_LOGFILE: $NAGIOS_LOGFILE" >> "$file_log"
fi

if [[ -z "$4$5" ]]; then
    echo "Missing arguments" >&2 >> "$file_log"
    exit STATUS_CRITICAL
fi
if [[ -z "$5" ]]; then
    SUBJECT=""
    MESSAGE="$4"
else
    SUBJECT="$5"
    MESSAGE="$4"
fi

curlres=$(curl -s --header 'Content-Type: application/json' --request 'POST' --data "{\"chat_id\":\"${3}\",\"text\":\"${SUBJECT}\n${MESSAGE}\"}" "${APIURL}")
curlerr="$?"
if [[ $curlerr -ne 0 ]]; then
    echo "Curl error:$curlerr" >&2 >> "$file_log"
    exit $STATUS_UNKNOWN;
fi
if [[ "$(echo "$curlres"|sed -En "s/^\{\"*ok\"*:([^,]*).*$/\1/p")" != "true" ]]; then
    echo "api.telegram error" >&2 >> "$file_log"
    echo "cmd=curl -s --header 'Content-Type: application/json' --request 'POST' --data \"{\"chat_id\":\"${3}\",\"text\":\"${SUBJECT}\n${MESSAGE}\"}\" \"${APIURL}\"" >&2 >> "$file_log"
    echo "result=$curlres" >&2 >> "$file_log"
      exit $STATUS_CRITICAL
fi

echo "Curl OK:$curlres" >&2 >> "$file_log"
exit $STATUS_OK