#!/bin/sh

set -o nounset
set -o errexit
set -o xtrace

usage() {
  /bin/cat <<EOF

Usage: $0 FILE [SYMBOL=VALUE]...

Download a kernel module (if necessary) and load it.

EOF
}

if [ -z "${1:-}" ]; then
  usage
  exit 1
fi

DNAS_SYSLOG_TAG="$(/usr/bin/basename "${0}")"
DNAS_BASE_URL="ftp://updates.drobo.com/droboapps/kernelmodules"
DNAS_BASE_DIR="/mnt/DroboFS/System/modules"
DNAS_DEVICE_MODEL="$(/usr/bin/cut -d' ' -f1 /sys/bus/scsi/devices/0:0:0:0/model)"
DNAS_KERNEL_RELEASE="$(/bin/uname -r)"
DNAS_MODULE_BASENAME="$(/usr/bin/basename "${1}" .ko)"
DNAS_MODULE_URL="${DNAS_BASE_URL}/${DNAS_DEVICE_MODEL}/${DNAS_KERNEL_RELEASE}/${DNAS_MODULE_BASENAME}.ko"
DNAS_MODULE_DIR="${DNAS_BASE_DIR}/${DNAS_DEVICE_MODEL}/${DNAS_KERNEL_RELEASE}"
DNAS_MODULE_FILE="${DNAS_MODULE_DIR}/${DNAS_MODULE_BASENAME}.ko"

if [ ! -d "/lib/modules/${DNAS_KERNEL_RELEASE}" ]; then
  /bin/mkdir -p "/lib/modules/${DNAS_KERNEL_RELEASE}" && rc=$? || rc=$?
  if [ ${rc} -ne 0 ]; then
    /usr/bin/logger -s -t "${DNAS_SYSLOG_TAG}" "ERROR: Unable to mkdir /lib/modules/${DNAS_KERNEL_RELEASE}, error code ${rc}; exiting."
    exit ${rc}
  fi
fi

if [ ! -d "${DNAS_MODULE_DIR}" ]; then
  /bin/mkdir -p "${DNAS_MODULE_DIR}" && rc=$? || rc=$?
  if [ ${rc} -ne 0 ]; then
    /usr/bin/logger -s -t "${DNAS_SYSLOG_TAG}" "ERROR: Unable to mkdir ${DNAS_MODULE_DIR}, error code ${rc}; exiting."
    exit ${rc}
  fi
fi

if (/sbin/lsmod | grep -q "^${DNAS_MODULE_BASENAME}"); then
  # already loaded
  exit 0
fi

if [ -f "${DNAS_MODULE_FILE}" ]; then
  shift
  /sbin/insmod "${DNAS_MODULE_FILE}" "$@"
  exit $?
fi

/usr/bin/wget -O "${DNAS_MODULE_FILE}.tmp" "${DNAS_MODULE_URL}" > "${DNAS_MODULE_DIR}/${DNAS_MODULE_BASENAME}.log" 2>&1 && rc=$? || rc=$?
if [ ${rc} -eq 0 ]; then
  /bin/mv -f "${DNAS_MODULE_FILE}.tmp" "${DNAS_MODULE_FILE}" && rc=$? || rc=$?
  if [ ${rc} -ne 0 ]; then
    /usr/bin/logger -s -t "${DNAS_SYSLOG_TAG}" "ERROR: Unable to mv ${DNAS_MODULE_FILE}.tmp ${DNAS_MODULE_FILE}, error code ${rc}; exiting."
    exit ${rc}
  fi
  shift
  /sbin/insmod "${DNAS_MODULE_FILE}" "$@"
  exit $?
fi

/usr/bin/logger -s -t "${DNAS_SYSLOG_TAG}" "ERROR: Unable to download ${DNAS_MODULE_URL}, error code ${rc}; see ${DNAS_MODULE_DIR}/${DNAS_MODULE_BASENAME}.log for more information."
exit ${rc}
