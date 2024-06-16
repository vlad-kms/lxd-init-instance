#!/bin/bash

#set -o pipefail

STATUS_OK=0;
STATUS_WARNING=1;
STATUS_CRITICAL=2;
STATUS_UNKNOWN=3;

if [[ -n $6 ]]; then
    echo "1: $1" >> /var/log/123.txt
    echo "2: $2" >> /var/log/123.txt
    echo "3: $3" >> /var/log/123.txt
    echo "4: $4" >> /var/log/123.txt
    echo "5: $5" >> /var/log/123.txt
    echo "6: $6" >> /var/log/123.txt
    echo "7: $7" >> /var/log/123.txt
    echo "8: $8" >> /var/log/123.txt
fi

APIURL="https://api.telegram.org/bot${2}/sendMessage"

if [[ -z "$4$5" ]]; then
    echo "Missing arguments" >&2
    exit STATUS_CRITICAL
fi
if [[ -z "$5" ]]
 then
  SUBJECT=""
  MESSAGE="$4"
 else
  SUBJECT="$5"
  MESSAGE="$4"
fi

curlres=$(curl -s --header 'Content-Type: application/json' --request 'POST' --data "{\"chat_id\":\"${3}\",\"text\":\"${SUBJECT}\n${MESSAGE}\"}" "${APIURL}")
curlerr="$?"
if [[ $curlerr -ne 0 ]]; then
    echo "Curl error:$curlerr" >&2 >> /var/log/123.txt
    exit $STATUS_UNKNOWN;
fi
if [[ "$(echo "$curlres"|sed -En "s/^\{\"*ok\"*:([^,]*).*$/\1/p")" != "true" ]]; then
   echo "api.telegram error" >&2
   echo "cmd=curl -s --header 'Content-Type: application/json' --request 'POST' --data \"{\"chat_id\":\"${3}\",\"text\":\"${SUBJECT}\n${MESSAGE}\"}\" \"${APIURL}\"" >&2
   echo "result=$curlres" >&2
   exit $STATUS_CRITICAL
fi

exit $STATUS_OK