#!/bin/sh
[[ -f /usr/sbin/n2ensite ]] && {
  chmod +x /usr/sbin/n2ensite
  ln -s /usr/sbin/n2ensite /usr/sbin/n2e
}
[[ -f /usr/sbin/n2dissite ]] && {
  chmod +x /usr/sbin/n2dissite
  ln -s /usr/sbin/n2dissite /usr/sbin/n2d
}
