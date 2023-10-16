
function _log () {
    local _type=${1:INFO}
    shift

    local prefix=" "
    if [ -n "$LOG_PREFIX" ] ; then
      prefix="[${LOG_PREFIX}] "
    fi
    if [ -r /var/run/syslogd.pid ] || [ -r /var/run/rsyslogd.pid ] ; then
      logger "${_type} ${prefix}$*"
    else
      echo "$(date '+%Y-%m-%d %H:%M:%S')     ${_type} ${prefix}$*"
    fi
}
function _warn() {
    _log "WARN" "$*"
}

function _info() {
    _log "INFO" "$*"
}

function _error() {
    _log "ERROR" "$*"
}

function _die() {
    _error "$1"
    kill -SIGQUIT 1
    exit
}

function prerun() {
  if [ -r /prerun.sh ] ; then
    source /prerun.sh
  else
    _info "Prerun script not found"
  fi
}

function show_logo() {
  cat <<EOF

░██████╗░██████╗██╗░░██╗███╗░░██╗░█████╗░░█████╗░░░░░█████╗░░█████╗░███╗░░░███╗
██╔════╝██╔════╝██║░░██║████╗░██║██╔══██╗██╔══██╗░░░██╔══██╗██╔══██╗████╗░████║
╚█████╗░╚█████╗░███████║██╔██╗██║██║░░██║██║░░╚═╝░░░██║░░╚═╝██║░░██║██╔████╔██║
░╚═══██╗░╚═══██╗██╔══██║██║╚████║██║░░██║██║░░██╗░░░██║░░██╗██║░░██║██║╚██╔╝██║
██████╔╝██████╔╝██║░░██║██║░╚███║╚█████╔╝╚█████╔╝██╗╚█████╔╝╚█████╔╝██║░╚═╝░██║
╚═════╝░╚═════╝░╚═╝░░╚═╝╚═╝░░╚══╝░╚════╝░░╚════╝░╚═╝░╚════╝░░╚════╝░╚═╝░░░░░╚═╝

EOF
if [ -n "$*" ] ; then
  echo -e "$*"
fi

}
