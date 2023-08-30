after_start() {
  cmd="lxc exec ${CONTAINER_NAME} --"
    # ssh настройка
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
    # установка и настройка acme.sh
  $cmd sh -c "curl -s https://get.acme.sh | sh -s email=9141778236@mail.ru > /dev/null"
  HOME_ACME="/root/.acme.sh"
  #
  CERT_NAME="av.t.mrovo.ru"
  CERT_NAME="av1.t.mrovo.ru"
  DOMAINS="-d ${CERT_NAME}"
  # провайдер acme ssl
  $cmd ${HOME_ACME}/acme.sh --set-default-ca --server ${DEFAULT_SSL_PROV}
    # получить первый раз сертификат
  rcf=${REQUEST_CERTIFICATE_FIRST:="1"}
  if [[ "$REQUEST_CERTIFICATE_FIRST" -ne "0" ]]; then
    $cmd sh -c "export SL_Key=${SL_KEY} && ${HOME_ACME}/acme.sh --issue --force --dns dns_selectel ${DOMAINS}" ### > /dev/null"
  fi
    # установка сертификата для nginx
  rcmd=${RELOAD_CMD:="systemctl -f reload nginx"}
  scmd=${START_CMD:="systemctl start nginx"}
  rscmd=${RESTART_CMD:="systemctl restart nginx"}
  $cmd sh -c "[[ -d /etc/nginx/snippets/certs/${CERT_NAME} ]] || mkdir -p /etc/nginx/snippets/certs/${CERT_NAME}"
  $cmd ${HOME_ACME}/acme.sh --install-cert -d ${CERT_NAME} --key-file /etc/nginx/snippets/certs/${CERT_NAME}/key.pem --fullchain-file /etc/nginx/snippets/certs/${CERT_NAME}/cert.pem --reloadcmd "${rcmd}"
}
