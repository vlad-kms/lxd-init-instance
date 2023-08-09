debug "Run ${0}:hook-afterstart.sh"
cmd="lxc exec ${CONTAINER_NAME} --"

tmpfile1=$($cmd mktemp)
$cmd bash -c "cat << EOF > ${tmpfile1}
Match Address 192.168.15.0/24,192.168.16.0/24
    PermitRootLogin yes
    PasswordAuthentication no
    PubkeyAcceptedKeyTypes ssh-ed25519,ssh-rsa,rsa-sha2-256,rsa-sha2-512
EOF"
$cmd sh -c "cat ${tmpfile1} >> /etc/ssh/sshd_config"
$cmd rm ${tmpfile1}
