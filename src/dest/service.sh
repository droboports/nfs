#!/usr/bin/env sh
#
# NFSv3 server

# import DroboApps framework functions
. /etc/service.subr

### app-specific section

# DroboApp framework version
framework_version="2.0"

# app description
name="nfs"
version="1.3.2"
description="NFS v3 server"

# framework-mandated variables
pidfile="/tmp/DroboApps/${name}/pid.txt"
logfile="/tmp/DroboApps/${name}/log.txt"
statusfile="/tmp/DroboApps/${name}/status.txt"
errorfile="/tmp/DroboApps/${name}/error.txt"

# app-specific variables
prog_dir="$(dirname $(realpath ${0}))"
rpcbind="${prog_dir}/bin/rpcbind"
mountd="${prog_dir}/sbin/rpc.mountd"
statd="${prog_dir}/sbin/rpc.statd"
nfsd="${prog_dir}/sbin/rpc.nfsd"
smnotify="${prog_dir}/sbin/sm-notify"

statuser="nobody"
mountpoint="/proc/fs/nfsd"
lockfile="/tmp/DroboApps/${name}/rpcbind.lock"

# _is_pid_running
# $1: daemon
# $2: pidfile
# returns: 0 if pid is running, 1 if not running or if pidfile does not exist.
_is_pid_running() {
  start-stop-daemon -K -t -x "${1}" -p "${2}" -q
}

# _is_daemon_running
# $1: daemon
# returns: 0 if daemon is running, 1 if not running.
_is_daemon_running() {
  start-stop-daemon -K -t -x "${1}" -q
}

# _is_name_running
# returns: 0 if process name is running, 1 if not running.
_is_name_running() {
  killall -0 "${1}" 2> /dev/null
}

# _kill_pid
# $1: daemon
# $2: pidfile
_kill_pid() {
  if _is_pid_running "${1}" "${2}"; then
    start-stop-daemon -K -x "${1}" -p "${2}" -q
  fi
}

# _kill_daemon
# $1: daemon
_kill_daemon() {
  if _is_daemon_running "${1}"; then
    start-stop-daemon -K -x "${1}" -q
  fi
}

# _kill_name
# $1: process name
_kill_name() {
  if _is_name_running "${1}"; then
    killall -9 "${1}"
  fi
}

# _is_running
# returns: 0 if app is running, 1 if not running.
_is_running() {
  if ! _is_name_running "nfsd"; then return 1; fi
  if ! _is_daemon_running "${statd}"; then return 1; fi
  if ! _is_daemon_running "${mountd}"; then return 1; fi
  if ! _is_pid_running "${rpcbind}" "${pidfile}"; then return 1; fi
  if [[ -z "$(grep ^nfsd /proc/mounts)" ]]; then return 1; fi
  return 0;
}

# _is_stopped
# returns: 0 if stopped, 1 if running.
_is_stopped() {
  if _is_name_running "nfsd"; then return 1; fi
  if _is_daemon_running "${statd}"; then return 1; fi
  if _is_daemon_running "${mountd}"; then return 1; fi
  if _is_pid_running "${rpcbind}" "${pidfile}"; then return 1; fi
  if [[ ! -z "$(grep ^nfsd /proc/mounts)" ]]; then return 1; fi
  return 0;
}

# returns a string like "3.2.0 [8.45.72385]"
#         or nothing if nasd is not running
_firmware_version() {
  local line
  /usr/bin/nc 127.0.0.1 5000 2> "${logfile}" | while read line; do
    if (echo ${line} | grep -q mVersion); then
      echo ${line} | sed 's|.*<mVersion>\(.*\)</mVersion>.*|\1|g'
      break;
    fi
  done
}

_load_modules() {
  local kversion="$(uname -r)"
  local modules="exportfs nfsd"
  for ko in ${modules}; do
    if [[ -z "$(lsmod | grep ^${ko})" ]]; then
      insmod "${prog_dir}/modules/${kversion}/${ko}.ko"
    fi
  done
}

start() {
  set -u # exit on unset variable
  set -e # exit on uncaught error code
  set -x # enable script trace
  local force_restart=0
  if [[ ! -f /etc/services ]]; then cp -v "${prog_dir}/etc/services" /etc/services; fi
  chmod 4511 "${prog_dir}/sbin/mount.nfs"
  chown -R "${statuser}" "${prog_dir}/var/lib/nfs/sm" \
                         "${prog_dir}/var/lib/nfs/sm.bak" \
                         "${prog_dir}/var/lib/nfs/state"
  _load_modules

  if [[ -z "$(grep ^nfsd /proc/mounts)" ]]; then
    mount -t nfsd nfsd "${mountpoint}"
  fi

  _kill_daemon "${smnotify}"

  if ! _is_pid_running "${rpcbind}" "${pidfile}"; then
    force_restart=1
    setsid "${rpcbind}" -d & echo $! > "${pidfile}"
    sleep 1
  fi

  if [[ ${force_restart} -eq 1 ]]; then
    _kill_name "nfsd"
    _kill_daemon "${statd}"
    _kill_daemon "${mountd}"
  fi

  if ! _is_daemon_running "${mountd}"; then
    setsid "${mountd}" -F -d auth &
  fi

  if ! _is_daemon_running "${statd}"; then
    setsid "${statd}" -F -d &
  fi

  if ! _is_name_running "nfsd"; then
    setsid "${prog_dir}/sbin/rpc.nfsd" -d 3
  fi

  reload_service
}

# override /etc/service.subrc
stop_service() {
  if _is_stopped; then
    echo ${name} is not running >&3
    if [[ "${1:-}" == "-f" ]]; then
      return 0
    else
      return 1
    fi
  fi

  _kill_name "nfsd"
  _kill_daemon "${smnotify}"
  _kill_daemon "${statd}"
  _kill_daemon "${mountd}"
  _kill_pid "${rpcbind}" "${pidfile}"

  if [[ -n "$(grep ^nfsd /proc/mounts)" ]]; then
    umount "${mountpoint}"
  fi
}

reload_service() {
  "${prog_dir}/sbin/exportfs" -ra
}

### common section

# script hardening
set -o errexit  # exit on uncaught error code
set -o nounset  # exit on unset variable

# ensure log folder exists
if ! grep -q ^tmpfs /proc/mounts; then mount -t tmpfs tmpfs /tmp; fi
logfolder="$(dirname ${logfile})"
if [[ ! -d "${logfolder}" ]]; then mkdir -p "${logfolder}"; fi

# redirect all output to logfile
exec 3>&1 1>> "${logfile}" 2>&1

# log current date, time, and invocation parameters
echo $(date +"%Y-%m-%d %H-%M-%S"): ${0} ${@}

_service_start() {
  if _is_running; then
    echo ${name} is already running >&3
    return 1
  fi
  set +x # disable script trace
  set +e # disable error code check
  set +u # disable unset variable check
  start_service
}

_service_stop() {
  stop_service
}

_service_waitstop() {
  stop_service -f
  while ! _is_stopped; do
    sleep 1
  done
}

_service_restart() {
  _service_waitstop
  _service_start
}

_service_reload() {
  reload_service
}

_service_status() {
  status >&3
}

_service_help() {
  echo "Usage: $0 [start|stop|waitstop|reload|restart|status]" >&3
  exit 1
}

# enable script tracing
set -o xtrace

case "${1:-}" in
  start|stop|waitstop|reload|restart|status) _service_${1} ;;
  *) _service_help ;;
esac
