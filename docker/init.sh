#!/usr/bin/env sh
# Functions
LOG_PREFIX=init.sh
source /common.sh

# Defaults
MONIT_ADMIN_PASSWORD=${MONIT_ADMIN_PASSWORD:-admin}
WG_DISABLED=${WG_DISABLED:-"yes"}
WG0_INTERFACE=${WG0_INTERFACE:-"wg0"}
WG0_KEEPALIVE=${WG0_KEEPALIVE:-25}

function set_monit_local() {
  local local_conf=/etc/monit.d/local.conf

  if [ -r $local_conf ] ; then
    rm $local_conf
  fi

  cat <<EOF > $local_conf
set daemon 30
set log syslog

set pidfile /var/run/monit/monit.pid
set idfile /var/run/monit/monit.id
set statefile /var/run/monit/monit.state

set httpd port 2812 and
    allow admin:$MONIT_ADMIN_PASSWORD

check system \$HOST
  if loadavg (1min) per core > 2 for 5 cycles then alert
  if loadavg (5min) per core > 1.5 for 10 cycles then alert
  if cpu usage > 95% for 10 cycles then alert
  if memory usage > 75% then alert
  if swap usage > 25% then alert
EOF

  if [ -n "$MONIT_MAILSERVER" ] && [ -n "$MONIT_OWNER" ] ; then
    cat <<EOF >> $local_conf
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
    _info "Monit e-amil alert config $local_conf created"
  else
    _warn "Monit e-mail alert is not set and disabled"
  fi
  _info "Monit local config created"
}

set_monit_wireguard() {
  local wireguard_conf=/etc/monit.d/wireguard.conf

  if [ -r $wireguard_conf ] ; then
    rm $wireguard_conf
  fi

  if [ "$WG_DISABLED" == "yes"  ] ; then
    _warn "Wireguard is disabled"
    return
  fi

  if [ -z "$WG0_ENDPOINT" ] ; then
    _warn "Set WG0_ENDPOINT environment variable! Wireguard is disabled."
    return
  fi

  if [ -z "$WG0_ENDPOINT_PORT" ] ; then
    _warn "Set WG0_ENDPOINT_PORT environment variable! Wireguard is disabled."
    return
  fi

  if [ -z "$WG0_INTERFACE" ] ; then
    _warn "Set WG0_INTERFACE environment variable! Wireguard is disabled."
    return
  fi

  cat <<EOF > $wireguard_conf
# STATUS_WG_TIMEOUT=5
# STATUS_WG_DISABLED=3

check program wireguard with path "/wireguard.sh --check"
  with timeout 10 seconds
  if status = 5 then exec "/wireguard.sh --restart"
  if status = 3 then unmonitor
  if status = 1 then unmonitor

check network $WG0_INTERFACE with interface $WG0_INTERFACE
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

  _info "Monit Wireguard config created"
}

function set_monit_pinger() {
  local pinger_conf=/etc/monit.d/pinger.conf

  if [ -r $pinger_conf ] ; then
    rm $pinger_conf
  fi

  if [ -n "$PINGER_ADDRESS" ] ; then
    cat <<EOF >> $pinger_conf
check host pinger with address $PINGER_ADDRESS
  if failed ping count 1 then alert
EOF
    _info "Monit Pinger config created"
  else
    _warn "Pinger is disabled"
  fi
}

function set_monit_rsyslog() {
  local rsyslog_conf=/etc/monit.d/rsyslog.conf

  if [ -r $rsyslog_conf ] ; then
    rm $rsyslog_conf
  fi

  cat <<EOF >> $rsyslog_conf
check file rsyslogd_mark with path /var/log/messages
  if timestamp > 65 minutes then alert
EOF

  _info "Monit rsyslog config created"
}

function set_wireguard_wg0() {
  if [ -n "$WG_DISABLED" ] && [ "$WG_DISABLED" == "yes"  ] ; then
    # _info "Wireguard is disabled"
    return
  fi

  if [ -z "$WG0_INTERFACE" ] ; then
    _error "Set WG0_INTERFACE environment variable"
    return
  fi

  local wg0_conf=/etc/wireguard/${WG0_INTERFACE}.conf

  if [ -r $wg0_conf ] ; then
    # rm $wg0_conf
    _warn "Wireguard config $wg0_conf found. Environment variables not used."
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
PersistentKeepalive = $WG0_KEEPALIVE
EOF

  chmod 600 $wg0_conf
  _info "Wireguard config created"
}

function exec_monit() {
  exec /usr/bin/monit -I
}

function start_monit() {
  /usr/bin/monit
}

# function exec_syslog() {
#   exec /sbin/syslogd -n -L -D -O -
#   /sbin/syslogd -L -b 0 -D
# }

function start_rsyslog() {
  /usr/sbin/rsyslogd
}

function start_wireguard() {
  /wireguard.sh --start
}

function main() {
  prerun

  show_logo "Image: $IMAGE_NAME\nGit Revision: $GIT_REV\nBuild Date: $BUILD_DATE\n"

  start_rsyslog

  set_monit_local
  set_monit_wireguard
  set_monit_pinger
  # set_monit_rsyslog

  set_wireguard_wg0
  start_wireguard

  # start_monit
  exec_monit
}

main $*


