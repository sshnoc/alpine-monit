#!/usr/bin/env sh
# Functions
LOG_PREFIX=init.sh
source /common.sh

function prerun() {
  if [ -r /prerun.sh ] ; then
    source /prerun.sh
  else
    _info "Prerun script not found"
  fi
}

function set_monit_alert() {
  local alert_conf=/etc/monit.d/alert.conf

  if [ -r $alert_conf ] ; then
    rm $alert_conf
  fi

  if [ -n "$MONIT_MAILSERVER" ] && [ -n "$MONIT_OWNER" ] ; then
    cat <<EOF > $alert_conf
SET MAILSERVER $MONIT_MAILSERVER

set eventqueue
    basedir /var/run/monit/events  # set the base directory where events will be stored
    slots 100           # optionally limit the queue size

set mail-format {
  from:    \$HOST Monit <monit@\$HOST>
  subject: \$HOST - monit alert --  \$EVENT \$SERVICE
  message: \$EVENT Service \$SERVICE
                Date:        \$DATE
                Action:      \$ACTION
                Host:        \$HOST
                Description: \$DESCRIPTION

           Your faithful employee,
           Monit
}

set alert $MONIT_OWNER
EOF
    _info "Monit $alert_conf created"
  else
    _warn "Monit E-mail alert is not set and disabled"
  fi
}

set_monit_wireguard() {
  local wireguard_conf=/etc/monit.d/wireguard.conf

  if [ -r $wireguard_conf ] ; then
    rm $wireguard_conf
  fi

  if [ -n "$WG_DISABLED" ] && [ "$WG_DISABLED" == "yes"  ] ; then
    # _info "Wireguard is disabled"
    return
  fi

  if [ -z "$WG0_ENDPOINT" ] ; then
    _warn "Set WG0_ENDPOINT environment variable"
    return
  fi

  if [ -z "$WG0_ENDPOINT_PORT" ] ; then
    _warn "Set WG0_ENDPOINT_PORT environment variable"
    return
  fi

  cat <<EOF > $wireguard_conf
check program wireguard with path "/wireguard.sh --check"
  with timeout 10 seconds
  if status = 5 then exec "/wireguard.sh --restart"
  if status = 3 then unmonitor
  if status = 1 then unmonitor

# TODO
check network wg0 with interface wg0
  depends wireguard
  if link down then alert

check host $WG0_ENDPOINT with address $WG0_ENDPOINT
  if failed ping count 1 then alert
  if failed 
    port $WG0_ENDPOINT_PORT 
    type TCP 
    protocol HTTPS
    status 403
  then alert

EOF

  if [ -z "$WG0_GATEWAY" ] ; then
    _warn "Set WG0_GATEWAY environment variable"
  else
    cat <<EOF >> $wireguard_conf
check host wg_gateway with address $WG0_GATEWAY
  depends wireguard
  if failed ping
  then exec /wireguard.sh --restart repeat every 5 cycle

EOF
  fi

  _info "Monit $wireguard_conf created"
}

function set_wg0() {
  local wg0_conf=/etc/wireguard/wg0.conf

  if [ -r $wg0_conf ] ; then
    # rm $wg0_conf
    _warn "Wireguard config $wg0_conf found. Environment variables not used."
    return
  fi

  if [ -n "$WG_DISABLED" ] && [ "$WG_DISABLED" == "yes"  ] ; then
    # _info "Wireguard is disabled"
    return
  fi

  if [ -z "$WG0_ADDRESS" ] ; then
    _error "Set WG0_ADDRESS environment variable"
    return
  fi

  if [ -z "$WG0_PUBLICKEY" ] ; then
    _error "Set WG0_PUBLICKEY environment variable"
    return
  fi

  if [ -z "$WG0_PRIVATEKEY" ] ; then
    _error "Set WG0_PRIVATEKEY environment variable"
    return
  fi

  if [ -z "$WG0_PSK" ] ; then
    _error "Set WG0_PSK environment variable"
    return
  fi

  if [ -z "$WG0_ALLOWEDIPS" ] ; then
    _error "Set WG0_ALLOWEDIPS environment variable"
    return
  fi

  cat <<EOF > $wg0_conf
[Interface]
PrivateKey = $WG0_PRIVATEKEY
Address = $WG0_ADDRESS

[Peer]
PublicKey = $WG0_PUBLICKEY
PresharedKey = $WG0_PSK
Endpoint = $WG0_ENDPOINT:$WG0_ENDPOINT_PORT
AllowedIPs = $WG0_ALLOWEDIPS
PersistentKeepalive = 25
EOF

  chmod 600 $wg0_conf
  _info "Wireguard config $wg0_conf created"
}

function exec_monit() {
  exec /usr/bin/monit -I
}

function start_monit() {
  /usr/bin/monit
}

function exec_syslog() {
  exec /sbin/syslogd -n -L -D -O -
}

function start_syslog() {
  # /sbin/syslogd -L -b 0 -D
  /usr/sbin/rsyslogd
}

function start_wireguard() {
  /wireguard.sh --start
}

function main() {
  start_syslog
  set_monit_alert
  set_monit_wireguard
  set_wg0
  prerun
  # exec_monit
  start_wireguard
  sleep 1
  start_monit
  sleep 1
  exec /usr/bin/tail -f -n +1 /var/log/messages
}

main $*


