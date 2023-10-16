#!/usr/bin/env sh
# Functions
LOG_PREFIX=wireguard.sh
source /common.sh

# Wireguard
# https://wiki.alpinelinux.org/wiki/Configure_a_Wireguard_interface_(wg)

WG_DISABLED=${WG_DISABLED:-"yes"}
WG0_INTERFACE=${WG0_INTERFACE:-"wg0"}

WG0_CONFIG=/etc/wireguard/${WG0_INTERFACE}.conf
WG0_PING_PERIOD=${WG0_PING_PERIOD:-10000}
RESTART_LOCK=""

# Return status
STATUS_WG_TIMEOUT=5
STATUS_WG_DISABLED=3

function is_ifup() {
  ip a show $WG0_INTERFACE up &> /dev/null
}

function start_wireguard() {
  local _func="start_wireguard"
  if [ ! -r $WG0_CONFIG ] ; then
    _warn "(${_func}) Wireguard configuration not found!"
    return 1
  fi

  if is_ifup ; then
    _info "(${_func}) Wireguard interface is already up"
    return 0
  fi

  WG0_ENDPOINT=$(cat $WG0_CONFIG | grep Endpoint | sed s/\ //g | cut -d= -f2)
  WG0_ADDRESS=$(cat $WG0_CONFIG | grep Address | sed s/\ //g | cut -d= -f2)
  WG0_PUBLICKEY=$(cat $WG0_CONFIG | grep PublicKey | sed s/\ //g | cut -d= -f2)
  WG0_GATEWAY=$(cat $WG0_CONFIG | grep CheckGateway | sed s/\ //g | cut -d= -f2)
  _info "(${_func}) Start Wireguard Interface: $WG0_INTERFACE"
  _info "      Endpoint: $WG0_ENDPOINT"
  _info "    My Address: $WG0_ADDRESS"
  _info " My Public Key: $WG0_PUBLICKEY"
  wg-quick up $WG0_INTERFACE 2>&1 > /var/${WG0_INTERFACE}.log
  sleep 2
  wg show 2>&1 >> /var/${WG0_INTERFACE}.log
  _info "(${_func}) Wireguard logs: /var/${WG0_INTERFACE}.log"
}

function stop_wireguard() {
  local _func="start_wireguard"
  if [ ! -r $WG0_CONFIG ] ; then
    _warn "(${_func}) Wireguard configuration not found!"
    return 1
  fi

  if ! is_ifup ; then
    _info "(${_func}) Wireguard interface is already down"
    return 0
  fi

  wg-quick down $WG0_INTERFACE
}

function main() {
  # set

  local action=${1:---start}
  local exit_status=0

  if [ "$WG_DISABLED" == "yes"  ] ; then
    exit $STATUS_WG_DISABLED
  fi

  if [ -r "$RESTART_LOCK" ] ; then
    _info "(${_func}) Wireguard is restarting"
    return 0
  fi

  # _info "Action: $action"

  if [ "${action}" == "--start" ] ; then
    start_wireguard
    exit $?
  fi

  if [ "${action}" == "--stop" ] ; then
    stop_wireguard
    exit $?
  fi

  if [ "${action}" == "--status" ] ; then
    wg show
    exit $?
  fi

  if [ "${action}" == "--check" ] ; then
    wg show $WG0_INTERFACE 2> /dev/null | grep 'latest handshake' &> /dev/null
    if [ $? -gt 0 ] ; then
      exit $STATUS_WG_TIMEOUT
    fi
  fi

  if [ "${action}" == "--restart" ] ; then

    RESTART_LOCK=$(mktemp)
  
    stop_wireguard
    sleep 2
    start_wireguard
    exit_status=$?
  
    rm -f $RESTART_LOCK
    exit $exit_status
  fi
}

main $*
