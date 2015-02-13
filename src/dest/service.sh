#!/usr/bin/env sh
#
# NFSv3 server

# import DroboApps framework functions
source /etc/service.subr

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
prog_dir="$(dirname $(readlink -fn ${0}))"

rpcbind="${prog_dir}/bin/rpcbind"
mountd="${prog_dir}/sbin/rpc.mountd"
daemon="${prog_dir}/sbin/rpc.nfsd"
statd="${prog_dir}/sbin/rpc.statd"
notify="${prog_dir}/sbin/sm-notify"

statuser="nobody"
mountpoint="/proc/fs/nfsd"
lockfile="/tmp/DroboApps/${name}/rpcbind.lock"
rpcbind_pid="/tmp/DroboApps/${name}/rpcbind.pid"
statd_pid="/tmp/DroboApps/${name}/rpc.statd.pid"
notify_pid="/tmp/DroboApps/${name}/sm-notify.pid"

# _is_pid_running
# $1: daemon
# $2: pidfile
# returns: 0 if pid is running, 1 if not running or if pidfile does not exist.
_is_pid_running() {
  /sbin/start-stop-daemon -K -s 0 -x "$1" -p "$2" -q
}

# _is_nfsd_running
# returns: 0 if nfsd is running, 1 if not running.
_is_nfsd_running() {
  /usr/bin/pgrep nfsd > /dev/null
}

# _kill_pid
# $1: daemon
# $2: pidfile
_kill_pid() {
  if _is_pid_running "$1" "$2"; then
    /sbin/start-stop-daemon -K -s 15 -x "$1" -p "$2" -q
  fi
}

# _kill_nfsd
_kill_nfsd() {
  if _is_nfsd_running; then
    killall -9 nfsd
  fi
}

# _is_running
# returns: 0 if nfs is running, 1 if not running.
_is_running() {
  if ! _is_nfsd_running; then return 1; fi
  if ! _is_pid_running "${statd}" "${statd_pid}"; then return 1; fi
  if ! _is_pid_running "${mountd}" "${pidfile}"; then return 1; fi
  if ! _is_pid_running "${rpcbind}" "${rpcbind_pid}"; then return 1; fi
  if [[ -z "$(grep ^nfsd /proc/mounts)" ]]; then return 1; fi
  if [[ -z "$(lsmod | grep ^nfsd)" ]]; then return 1; fi
  if [[ -z "$(lsmod | grep ^exportfs)" ]]; then return 1; fi
  return 0;
}

start() {
  set -u # exit on unset variable
  set -e # exit on uncaught error code
  set -x # enable script trace
  /bin/chmod 4511 "${prog_dir}/sbin/mount.nfs"
  chown -R "${statuser}" "${prog_dir}/var/lib/nfs/sm" \
                         "${prog_dir}/var/lib/nfs/sm.bak" \
                         "${prog_dir}/var/lib/nfs/state"

  if [[ -z "$(lsmod | grep ^exportfs)" ]]; then
    /sbin/insmod "${prog_dir}/modules/$(uname -r)/exportfs.ko"
  fi

  if [[ -z "$(lsmod | grep ^nfsd)" ]]; then
    /sbin/insmod "${prog_dir}/modules/$(uname -r)/nfsd.ko"
  fi

  if [[ -z "$(grep ^nfsd /proc/mounts)" ]]; then
    /bin/mount -t nfsd nfsd "${mountpoint}"
  fi

  _kill_pid "${notify}" "${notify_pid}"

  if ! _is_pid_running "${rpcbind}" "${rpcbind_pid}"; then
    "${rpcbind}" -d & echo $! > "${rpcbind_pid}"
    sleep 1
  fi

  if ! _is_pid_running "${mountd}" "${pidfile}"; then
    "${mountd}" -F & echo $! > "${pidfile}"
    sleep 1
  fi

  if ! _is_pid_running "${statd}" "${statd_pid}"; then
    "${statd}" -F & echo $! > "${statd_pid}"
    sleep 1
  fi

  if ! _is_nfsd_running; then
    "${prog_dir}/sbin/rpc.nfsd" -d 3 &
  else
    _service_reload
  fi
}

# override /etc/service.subrc
stop_service() {
  _kill_nfsd
  _kill_pid "${notify}" "${notify_pid}"
  _kill_pid "${statd}" "${statd_pid}"
  _kill_pid "${mountd}" "${pidfile}"
  _kill_pid "${rpcbind}" "${rpcbind_pid}"

  if [[ -n "$(grep ^nfsd /proc/mounts)" ]]; then
    /bin/umount "${mountpoint}"
  fi

  if [[ ! -d "/lib/modules/$(uname -r)" ]]; then
    mkdir -p "/lib/modules/$(uname -r)"
  fi

  if [[ -z "$(lsmod | grep ^nfsd)" ]]; then
    /sbin/rmmod "nfsd"
  fi

  if [[ -z "$(lsmod | grep ^exportfs)" ]]; then
    /sbin/rmmod "exportfs"
  fi
}

### common section

# script hardening
set -o errexit  # exit on uncaught error code
set -o nounset  # exit on unset variable
set -o pipefail # propagate last error code on pipe

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

_service_restart() {
  _service_stop
  sleep 3
  _service_start
}

_service_reload() {
  "${prog_dir}/sbin/exportfs" -ra
}

_service_status() {
  status >&3
}

_service_help() {
  echo "Usage: $0 [start|stop|restart|reload|status]" >&3
  set +e # disable error code check
  exit 1
}

# enable script tracing
set -o xtrace

case "${1:-}" in
  start|stop|restart|reload|status) _service_${1} ;;
  *) _service_help ;;
esac
