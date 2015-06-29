#!/usr/bin/env sh
#
# NFSv3 server

# import DroboApps framework functions
. /etc/service.subr

framework_version="2.1"
name="nfs"
version="1.3.2-1"
description="NFS v3 server"
depends=""
webui=""

prog_dir="$(dirname $(realpath ${0}))"
rpcbind="${prog_dir}/bin/rpcbind"
mountd="${prog_dir}/sbin/rpc.mountd"
statd="${prog_dir}/sbin/rpc.statd"
nfsd="${prog_dir}/sbin/rpc.nfsd"
smnotify="${prog_dir}/sbin/sm-notify"
tmp_dir="/tmp/DroboApps/${name}"
logfile="${tmp_dir}/log.txt"
statusfile="${tmp_dir}/status.txt"
errorfile="${tmp_dir}/error.txt"
statuser="nobody"
mountpoint="/proc/fs/nfsd"
lockfile="${tmp_dir}/rpcbind.lock"

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

# _kill_daemon
# $1: daemon
# $2: signal (default 15)
_kill_daemon() {
  local _signal="${2:-15}"
  start-stop-daemon -K -s "${_signal}" -x "${1}" -q || true
}

# _kill_name
# $1: process name
# $2: signal (default 15)
_kill_name() {
  local _signal="${2:-15}"
  killall -${_signal} "${1}" || true
}

is_running() {
  if ! _is_name_running "nfsd"; then return 1; fi
  if ! _is_daemon_running "${statd}"; then return 1; fi
  if ! _is_daemon_running "${mountd}"; then return 1; fi
  if ! _is_daemon_running "${rpcbind}"; then return 1; fi
  return 0;
}

# _is_stopped
# returns: 0 if stopped, 1 if running.
is_stopped() {
  if _is_name_running "nfsd"; then return 1; fi
  if _is_daemon_running "${statd}"; then return 1; fi
  if _is_daemon_running "${mountd}"; then return 1; fi
  if _is_daemon_running "${rpcbind}"; then return 1; fi
  return 0;
}

# returns a string like "3.2.0 [8.45.72385]"
#         or nothing if nasd is not running
_firmware_version() {
  local line
  timeout -t 1 /usr/bin/nc 127.0.0.1 5000 2> "${logfile}" | while read line; do
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
    if [ -z "$(lsmod | grep ^${ko})" ]; then
      insmod "${prog_dir}/modules/${kversion}/${ko}.ko"
    fi
  done
}

start() {
  if [ ! -f /etc/services ]; then
    cp -v "${prog_dir}/etc/services" /etc/services
  fi
  chmod 4511 "${prog_dir}/sbin/mount.nfs"
  chown -R "${statuser}" "${prog_dir}/var/lib/nfs/sm" \
                         "${prog_dir}/var/lib/nfs/sm.bak" \
                         "${prog_dir}/var/lib/nfs/state"
  _load_modules

  if [ -z "$(grep ^nfsd /proc/mounts)" ]; then
    mount -t nfsd nfsd "${mountpoint}"
  fi

  _kill_daemon "${smnotify}"

  if ! _is_daemon_running "${rpcbind}"; then
    "${rpcbind}"
    sleep 1
    _kill_name "nfsd"
    _kill_daemon "${statd}"
    _kill_daemon "${mountd}"
  fi

  if ! _is_daemon_running "${mountd}"; then
    "${mountd}" -d auth
  fi

  if ! _is_daemon_running "${statd}"; then
    setsid "${statd}" -d &
  fi

  if ! _is_name_running "nfsd"; then
    setsid "${prog_dir}/sbin/rpc.nfsd" -d 3
  fi

  reload
}

stop() {
  _kill_name "nfsd"
  _kill_daemon "${smnotify}"
  _kill_daemon "${statd}"
  _kill_daemon "${mountd}"
  _kill_daemon "${rpcbind}"
  if [ -n "$(grep ^nfsd /proc/mounts)" ]; then
    umount "${mountpoint}"
  fi
}

force_stop() {
  _kill_name "nfsd" 9
  _kill_daemon "${smnotify}" 9
  _kill_daemon "${statd}" 9
  _kill_daemon "${mountd}" 9
  _kill_daemon "${rpcbind}" 9
  if [ -n "$(grep ^nfsd /proc/mounts)" ]; then
    umount -lf "${mountpoint}"
  fi
}

reload() {
  "${prog_dir}/sbin/exportfs" -ra
}

# boilerplate
if ! grep -q ^tmpfs /proc/mounts; then mount -t tmpfs tmpfs /tmp; fi
if [ ! -d "${tmp_dir}" ]; then mkdir -p "${tmp_dir}"; fi
exec 3>&1 4>&2 1>> "${logfile}" 2>&1
STDOUT=">&3"
STDERR=">&4"
echo "$(date +"%Y-%m-%d %H-%M-%S"):" "${0}" "${@}"
set -o errexit  # exit on uncaught error code
set -o nounset  # exit on unset variable
set -o xtrace   # enable script tracing

main "${@}"
