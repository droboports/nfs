#!/usr/bin/env sh
#
# install script

prog_dir="$(dirname "$(realpath "${0}")")"
name="$(basename "${prog_dir}")"
tmp_dir="/tmp/DroboApps/${name}"
logfile="${tmp_dir}/install.log"
incron_dir="/etc/incron.d"

# boilerplate
if [ ! -d "${tmp_dir}" ]; then mkdir -p "${tmp_dir}"; fi
exec 3>&1 4>&2 1>> "${logfile}" 2>&1
echo "$(date +"%Y-%m-%d %H-%M-%S"):" "${0}" "${@}"
set -o errexit  # exit on uncaught error code
set -o nounset  # exit on unset variable
set -o xtrace   # enable script tracing

if [ -d /var/lib/nfs ] && [ ! -h /var/lib/nfs]; then
  mv -f /var/lib/nfs/* "${prog_dir}/var/lib/nfs/"
  rmdir /var/lib/nfs
fi
ln -fs "${prog_dir}/var/lib/nfs" /var/lib/

# copy default configuration files
find "${prog_dir}" -type f -name "*.default" -print | while read deffile; do
  basefile="$(dirname "${deffile}")/$(basename "${deffile}" .default)"
  if [ ! -f "${basefile}" ]; then
    cp -vf "${deffile}" "${basefile}"
  fi
done

if [ -d "${incron_dir}" ] && [ ! -f "${incron_dir}/${name}" ]; then
  cp -f "${prog_dir}/${name}.incron" "${incron_dir}/${name}"
fi

# install apache 2.x
/usr/bin/DroboApps.sh install_version apache 2
