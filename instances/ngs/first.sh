#!/bin/sh

#ln -f -s /etc/apache2/sites-available/nagios.conf /etc/apache2/conf.d
#ln -f -s /etc/nagios/cgi.cfg /etc/apache2/conf.d

htpasswd -mbc /etc/nagios/htpasswd.users vovka 030969

find /usr/share/nagios -type d -exec chmod 0755 '{}' \;
find /usr/share/nagios -type f -exec chmod 0644 '{}' \;

rc-service apache2 restart
rc-service nagios restart
