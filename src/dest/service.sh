#!/usr/bin/env sh
#
# NFSv3 server

# import DroboApps framework functions
. /etc/service.subr

framework_version="2.1"
name="nfs"
version="1.3.3"
description="Network File System (NFS) is a distributed file system protocol"
depends=""
webui="WebUI"

prog_dir="$(dirname "$(realpath "${0}")")"
daemon="${prog_dir}/libexec/monit"
tmp_dir="/tmp/DroboApps/${name}"
pidfile="${tmp_dir}/pid.txt"
logfile="${tmp_dir}/log.txt"
statusfile="${tmp_dir}/status.txt"
errorfile="${tmp_dir}/error.txt"
statuser="nobody"

conffile="${prog_dir}/etc/exports"
autofile="${conffile}.auto"
shares_conf="/mnt/DroboFS/System/DNAS/configs/shares.conf"
shares_dir="/mnt/DroboFS/Shares"
rescan=""

# check firmware version
_firmware_check() {
  local rc
  local semver
  rm -f "${statusfile}" "${errorfile}"
  if [ -z "${FRAMEWORK_VERSION:-}" ]; then
    echo "Unsupported Drobo firmware, please upgrade to the latest version." > "${statusfile}"
    echo "4" > "${errorfile}"
    return 1
  fi
  semver="$(/usr/bin/semver.sh "${framework_version}" "${FRAMEWORK_VERSION}")"
  if [ "${semver}" == "1" ]; then
    echo "Unsupported Drobo firmware, please upgrade to the latest version." > "${statusfile}"
    echo "4" > "${errorfile}"
    return 1
  fi
  return 0
}

# Download and load the required kernel modules
_load_modules() {
  local rc

  "${prog_dir}/libexec/dlmod.sh" "nfsd" && rc=$? || rc=$?
  if [ ${rc} -ne 0 ]; then
    echo "1" > "${errorfile}"
    echo "Unable to load kernel modules, please see log.txt for more information." > "${statusfile}"
    return 1
  fi
  return 0
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
  _firmware_check

  chmod 4511 "${prog_dir}/sbin/mount.nfs"
  chown -R "${statuser}" "${prog_dir}/var/lib/nfs/sm" \
                         "${prog_dir}/var/lib/nfs/sm.bak" \
                         "${prog_dir}/var/lib/nfs/state"
  _load_modules
  if ! grep -q '^nfsd' /proc/mounts; then mount -t nfsd nfsd /proc/fs/nfsd; fi
  cp -f "${prog_dir}/etc/netconfig.default" "${prog_dir}/etc/netconfig"

  if [ ! -f "${conffile}" ] && [ ! -f "${autofile}" ]; then
    touch "${conffile}"
    touch "${autofile}"
  fi
  reload

  "${prog_dir}/libexec/monit" -c "${prog_dir}/etc/monitrc"
  "${prog_dir}/libexec/monit" -c "${prog_dir}/etc/monitrc" start all
}

stop() {
  "${prog_dir}/libexec/monit" -c "${prog_dir}/etc/monitrc" stop all
  "${prog_dir}/libexec/monit" -c "${prog_dir}/etc/monitrc" quit
  killall -q -2 nfsd || true
  killall -q sm-notify rpc.statd rpc.mountd rpcbind || true
  start-stop-daemon -K -s 9 -x "${daemon}" -p "${pidfile}" -q || true
  if grep -q '^nfsd' /proc/mounts; then umount -lf /proc/fs/nfsd; fi
}

force_stop() {
  killall -q -9 nfsd sm-notify rpc.statd rpc.mountd rpcbind || true
  start-stop-daemon -K -s 9 -x "${daemon}" -p "${pidfile}" -q || true
  if grep -q "^nfsd" /proc/mounts; then umount -lf /proc/fs/nfsd; fi
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
