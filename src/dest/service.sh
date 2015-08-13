#!/usr/bin/env sh
#
# NFSv3 server

# import DroboApps framework functions
. /etc/service.subr

framework_version="2.1"
name="nfs"
version="1.3.2-2"
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

conffile="${prog_dir}/etc/exports"
autofile="${conffile}.auto"
shares_conf="/mnt/DroboFS/System/DNAS/configs/shares.conf"
shares_dir="/mnt/DroboFS/Shares"
rescan=""

# backwards compatibility
if [ -z "${FRAMEWORK_VERSION:-}" ]; then
  framework_version="2.0"
  . "${prog_dir}/libexec/service.subr"
fi

# _is_name_running
# returns: 0 if process name is running, 1 if not running.
_is_name_running() {
  killall -0 "${1}" 2> /dev/null
}

# _is_daemon_running
# $1: daemon
# returns: 0 if daemon is running, 1 if not running.
_is_daemon_running() {
  start-stop-daemon -K -t -x "${1}" -q
}

# _kill_name
# $1: process name
# $2: signal (default 15)
_kill_name() {
  killall -q -${2:-15} "${1}" || true
}

# _kill_daemon
# $1: daemon
# $2: signal (default 15)
_kill_daemon() {
  start-stop-daemon -K -s ${2:-15} -x "${1}" -q || true
}

is_running() {
#   if ! _is_name_running "nfsd"; then return 1; fi
#   if ! _is_daemon_running "${statd}"; then return 1; fi
#   if ! _is_daemon_running "${mountd}"; then return 1; fi
#   if ! _is_daemon_running "${rpcbind}"; then return 1; fi
  if _is_name_running "nfsd" || \
     _is_daemon_running "${statd}" || \
     _is_daemon_running "${mountd}" || \
     _is_daemon_running "${rpcbind}"; then
    return 0
  fi
  return 1;
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

# returns a string like "3.2.0 8.45.72385"
#         or nothing if nasd is not running
_firmware_version() {
  local line
  if (which esa > /dev/null) && (esa help | grep -q vxver); then
    esa vxver
  else
    # fallback when there is no esa or no vxver
    timeout -t 1 nc 127.0.0.1 5000 2> "${logfile}" | while read line; do
      if (echo ${line} | grep -q mVersion); then
        echo ${line} | sed 's|.*<mVersion>\(.*\)</mVersion>.*|\1|g'
        break;
      fi
    done
  fi
}

_load_modules() {
  local kversion="$(uname -r)"
  local fversion="$(_firmware_version)"
  local modules="nfsd"
  case "${fversion}" in
    3.5.*) kversion="${kversion}-3.5.0" ; modules="auth_rpcgss ${modules}" ;;
    3.3.*|3.2.*) kversion="${kversion}-3.2.0" ;;
    3.1.*|3.0.*) kversion="${kversion}" ;;
    *) eval echo "Unsupported firmware revision: ${fversion}" ${STDOUT}; return 1 ;;
  esac
  for ko in ${modules}; do
    if ! (lsmod | grep -q "^${ko}"); then
      insmod "${prog_dir}/modules/${kversion}/${ko}.ko"
    fi
  done
}

# Only shares that are exposed for 'Everyone' will be auto-published,
# since NFS does not support user authentication.
_load_shares() {
  local share_count
  local share_name
  local everyone

  touch "${autofile}.tmp"
  share_count=$("${prog_dir}/libexec/xmllint" --xpath "count(//Share)" "${shares_conf}")
  if [ ${share_count} -eq 0 ]; then
    echo "No shares found."
  else
    echo "Found ${share_count} shares."
    for i in $(seq 1 ${share_count}); do
      share_name=$("${prog_dir}/libexec/xmllint" --xpath "//Share[${i}]/ShareName/text()" "${shares_conf}")
      # $everyone == 1, rw; $everyone == 0, ro; $everyone == '', no access
      everyone=$("${prog_dir}/libexec/xmllint" --xpath "//Share[${i}]/ShareUsers/ShareUser[ShareUsername/text()='Everyone']/ShareUserAccess/text()" "${shares_conf}" 2> /dev/null) || true
      if [ -z "${everyone}" ]; then
        # no access for Everyone
        continue
      elif [ ${everyone} -eq 1 ]; then
        # Everyone has write access
        echo "${shares_dir}/${share_name} 0.0.0.0/0(rw,insecure,async,no_subtree_check,no_root_squash,anonuid=99,anongid=99)" >> "${autofile}.tmp"
        echo "${shares_dir}/${share_name} ::/128(rw,insecure,async,no_subtree_check,no_root_squash,anonuid=99,anongid=99)" >> "${autofile}.tmp"
      elif [ ${everyone} -eq 0 ]; then
        # Everyone has read-only access
        echo "${shares_dir}/${share_name} 0.0.0.0/0(ro,insecure,async,no_subtree_check,no_root_squash,anonuid=99,anongid=99)" >> "${autofile}.tmp"
        echo "${shares_dir}/${share_name} ::/128(ro,insecure,async,no_subtree_check,no_root_squash,anonuid=99,anongid=99)" >> "${autofile}.tmp"
      fi
    done
  fi

  if ! diff -q "${autofile}.tmp" "${autofile}"; then
    mv "${autofile}.tmp" "${autofile}"
    cp "${autofile}" "${conffile}"
  else
    rm -f "${autofile}.tmp"
  fi
}

start() {
  chmod 4511 "${prog_dir}/sbin/mount.nfs"
  chown -R "${statuser}" "${prog_dir}/var/lib/nfs/sm" \
                         "${prog_dir}/var/lib/nfs/sm.bak" \
                         "${prog_dir}/var/lib/nfs/state"
  _load_modules

  if ! grep -q "^nfsd" /proc/mounts; then
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

  if [ ! -f "${conffile}" ] && [ ! -f "${autofile}" ]; then
    touch "${conffile}"
    touch "${autofile}"
  fi

  if ! _is_name_running "nfsd"; then
    setsid "${prog_dir}/sbin/rpc.nfsd" -d 3
  fi

  reload
}

stop() {
  _kill_name "nfsd" 2
  _kill_daemon "${smnotify}"
  _kill_daemon "${statd}"
  _kill_daemon "${mountd}"
  _kill_daemon "${rpcbind}"
  if grep -q "^nfsd" /proc/mounts; then
    umount "${mountpoint}"
  fi
}

force_stop() {
  _kill_name "nfsd" 9
  _kill_daemon "${smnotify}" 9
  _kill_daemon "${statd}" 9
  _kill_daemon "${mountd}" 9
  _kill_daemon "${rpcbind}" 9
  if grep -q "^nfsd" /proc/mounts; then
    umount -lf "${mountpoint}"
  fi
}

reload() {
  if [ -f "${autofile}" ]; then
    _load_shares
  fi
  "${prog_dir}/sbin/exportfs" -ra
}

# boilerplate
if [ ! -d "${tmp_dir}" ]; then mkdir -p "${tmp_dir}"; fi
exec 3>&1 4>&2 1>> "${logfile}" 2>&1
STDOUT=">&3"
STDERR=">&4"
echo "$(date +"%Y-%m-%d %H-%M-%S"):" "${0}" "${@}"
set -o errexit  # exit on uncaught error code
set -o nounset  # exit on unset variable
set -o xtrace   # enable script tracing

main "${@}"
