echo "Run ${0}:hook-afterstart.sh"
cmd="lxc exec ${CONTAINER_NAME} --"
#$cmd chown -R named:named /etc/bind
$cmd chown -R named:named /var/bind
$cmd chmod -R 0600 /var/bind/keys
$cmd chmod 0700 /var/bind/keys
#$cmd chmod +x /run/start/script.sh

$cmd sh -c "echo \"Match Address 192.168.15.0/24,192.168.16.0/24\" >> /etc/ssh/sshd_config"
$cmd sh -c "echo \"    PermitRootLogin yes\" >>  /etc/ssh/sshd_config"
$cmd sh -c "echo \"    PasswordAuthentication no\" >>  /etc/ssh/sshd_config"
$cmd sh -c "echo \"    #PermitEmptyPasswords no\" >>  /etc/ssh/sshd_config"
$cmd sh -c "echo \"    #PubkeyAuthentication yes\" >>  /etc/ssh/sshd_config"
$cmd sh -c "echo \"    #AuthorizedKeysFile %h/.ssh/authorized_keys\" >>  /etc/ssh/sshd_config"
$cmd sh -c "echo \"    ##RhostsRSAAuthentication no\" >>  /etc/ssh/sshd_config"
$cmd sh -c "echo \"    #HostbasedAuthentication no\" >>  /etc/ssh/sshd_config"
$cmd sh -c "echo \"    #PermitEmptyPasswords no\" >>  /etc/ssh/sshd_config"
$cmd sh -c "echo \"    PubkeyAcceptedKeyTypes ssh-ed25519,ssh-rsa,rsa-sha2-256,rsa-sha2-512\" >>  /etc/ssh/sshd_config"
#lxc stop $CONTAINER_NAME
#lxc start $CONTAINER_NAME
