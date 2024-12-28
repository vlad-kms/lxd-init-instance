#!/bin/sh

chmod 0700 /root/easy-rsa
ln -s /usr/share/easy-rsa/* /root/easy-rsa/

rm -f ${0}
