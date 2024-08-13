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
  wd=/etc/nagios
  ${cmd} chmod 0755 "$wd"
  ${cmd} find "$wd" -type d -exec chmod 0755 {} \;
  ${cmd} find "${wd}/objects" -type f -exec chmod 0644 {} \;
  ${cmd} find "${wd}/servers" -type f -exec chmod 0644 {} \;
  ${cmd} find "${wd}/switches" -type f -exec chmod 0644 {} \;
  # configure /usr/lib/nagios
  wd=/usr/lib/nagios
  ${cmd} chmod 0755 "${wd}"
  # configure /usr/share/nagios4/htdocs/images/logos/eve
  wd=/usr/share/nagios4
  ${cmd} chmod 0755 "$wd"
  ${cmd} find "$wd" -type d -exec chmod 0755 {} \;
  # включиь службу nagios
  #${cmd} systemctl enable nagios4
  # очистить кэш
  #${cmd} apt-get clean
}

