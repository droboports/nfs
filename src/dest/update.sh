#!/usr/bin/env sh
#
# update script

prog_dir="$(dirname "$(realpath "${0}")")"
name="$(basename "${prog_dir}")"
conffile="${prog_dir}/etc/exports"
tmp_dir="/tmp/DroboApps/${name}"
logfile="${tmp_dir}/update.log"

# boilerplate
if [ ! -d "${tmp_dir}" ]; then mkdir -p "${tmp_dir}"; fi
exec 3>&1 4>&2 1>> "${logfile}" 2>&1
echo "$(date +"%Y-%m-%d %H-%M-%S"):" "${0}" "${@}"
set -o errexit  # exit on uncaught error code
set -o nounset  # exit on unset variable
set -o xtrace   # enable script tracing

/bin/sh "${prog_dir}/service.sh" stop

if [ -f "${conffile}" ]; then
  conffile_md5="$(/usr/bin/md5sum "${conffile}" | awk '{print $1}')"
  if [ "${conffile_md5}" == "5300e91448128c154f324cb331c36b77" ]; then
    # this is an untouched default configuration file, remove it
    rm -f "${conffile}"
  fi
fi
