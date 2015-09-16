#!/usr/bin/env sh
#
# empty uninstall script

prog_dir="$(dirname "$(realpath "${0}")")"
name="$(basename "${prog_dir}")"
tmp_dir="/tmp/DroboApps/${name}"
logfile="${tmp_dir}/uninstall.log"
incron_dir="/etc/incron.d"

# boilerplate
if [ ! -d "${tmp_dir}" ]; then mkdir -p "${tmp_dir}"; fi
exec 3>&1 4>&2 1>> "${logfile}" 2>&1
echo "$(date +"%Y-%m-%d %H-%M-%S"):" "${0}" "${@}"
set -o errexit  # exit on uncaught error code
set -o nounset  # exit on unset variable
set -o xtrace   # enable script tracing

if [ -e /var/lib/nfs ]; then
  rm -f /var/lib/nfs
fi

if [ -f "${incron_dir}/${name}" ]; then
  rm -f "${incron_dir}/${name}"
fi
