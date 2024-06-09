#!/bin/sh

after_init_container() {
  echo "DISPATH HOOK: after_init_container"
}

after_start() {
  echo "DISPATH HOOK: Run ${0}:hook-afterstart::after_start"
  echo "lxc_cmd: ${lxc_cmd}"
  cmd="${lxc_cmd} exec ${CONTAINER_NAME} -- "
  # configure apache2
  ${cmd} chmod 0755 /etc/apache2
  ${cmd} find /etc/apache2 -type d -exec chmod 0755 {} \;
  ${cmd} find /etc/apache2 -type f -exec chmod 0644 {} \;
  ${cmd} a2enmod cgi
  # configure nagios
  ${cmd} chmod 0755 /etc/nagios4
  ${cmd} find /etc/nagios4 -type d -exec chmod 0755 {} \;
  ${cmd} find /etc/nagios4/objects -type f -exec chmod 0644 {} \;
  ${cmd} find /etc/nagios4/servers -type f -exec chmod 0644 {} \;
  ${cmd} find /etc/nagios4/switches -type f -exec chmod 0644 {} \;
  ${cmd} systemctl enable nagios4 
}

