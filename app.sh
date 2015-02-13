export LIBATOMIC="${PWD}/target/linux-atomic"

### ATOMIC ###
_build_atomic() {
# The GCC toolchain for the DroboFS does not support
# atomic builtins. This is a workaround.
_download_file "linux-atomic.c" "https://gcc.gnu.org/git/?p=gcc.git;a=blob_plain;f=libgcc/config/arm/linux-atomic.c"

mkdir -p "target/linux-atomic"
cp -vf "download/linux-atomic.c" "target/linux-atomic/"
pushd "target/linux-atomic"
libtool --tag=CC --mode=compile "${CC}" ${CFLAGS} ${CPPFLAGS} -MT linux-atomic.lo -MD -MP -MF linux-atomic.Tpo -c -o linux-atomic.lo linux-atomic.c
libtool --tag=CC --mode=link "${CC}" ${CFLAGS} ${LDFLAGS} -o liblinux-atomic.la linux-atomic.lo
popd
}

### LIBTIRPC ###
_build_libtirpc() {
local VERSION="0.2.5"
local FOLDER="libtirpc-${VERSION}"
local FILE="${FOLDER}.tar.bz2"
local URL="http://sourceforge.net/projects/libtirpc/files/libtirpc/${VERSION}/${FILE}"

_download_bz2 "${FILE}" "${URL}" "${FOLDER}"
pushd "target/${FOLDER}"
./configure --host="${HOST}" --prefix="${DEPS}" --libdir="${DEST}/lib" --disable-static --disable-gssapi LDFLAGS="${LDFLAGS:-} -L${LIBATOMIC} -L${LIBATOMIC}/.libs" LIBS="-llinux-atomic"
make
make install
mkdir -p "${DEST}/etc"
cp -vf "${DEPS}/etc/netconfig" "${DEST}/etc/netconfig.default"
popd
}

### RPCBIND ###
_build_rpcbind() {
local VERSION="0.2.2"
local FOLDER="rpcbind-${VERSION}"
local FILE="${FOLDER}.tar.bz2"
local URL="http://sourceforge.net/projects/rpcbind/files/rpcbind/${VERSION}/${FILE}"
local SRC_INCLUDE="${PWD}/src/include"

_download_bz2 "${FILE}" "${URL}" "${FOLDER}"
pushd "target/${FOLDER}"
PKG_CONFIG_PATH="${DEST}/lib/pkgconfig" ./configure --host="${HOST}" --prefix="${DEST}" --mandir="${DEST}/man" --without-systemdsystemunitdir CPPFLAGS="${CPPFLAGS:-} -I${SRC_INCLUDE}" LDFLAGS="${LDFLAGS:-} -L${LIBATOMIC}/.libs" LIBS="-llinux-atomic"
make -j1
make install
popd
}

### LIBBLKID ###
_build_libblkid() {
# util-linux-2.22.2 is the last version that supports glibc-2.5
# v2.23 uses mkostemp, which requires at least glibc-2.7
local VERSION="2.22.2"
local FOLDER="util-linux-${VERSION}"
local FILE="${FOLDER}.tar.xz"
local URL="https://www.kernel.org/pub/linux/utils/util-linux/v2.22/${FILE}"

_download_xz "${FILE}" "${URL}" "${FOLDER}"
pushd "target/${FOLDER}"
./configure --host=arm-none-linux-gnueabi --prefix="${DEPS}" --libdir="${DEST}/lib" --disable-static --without-ncurses --disable-{mount,losetup,fsck,partx,uuidd,mountpoint,fallocate,unshare,arch,ddate,eject,agetty,cramfs,wdctl,switch_root,pivot_root,elvtune,kill,last,utmpdump,line,mesg,raw,rename,reset,vipw,newgrp,chfn-chsh,login,sulogin,su,schedutils,wall,write,chkdupexe} --enable-libblkid scanf_cv_alloc_modifier=as
make
make install
ln -vfs "libblkid.so.1.1.0" "${DEST}/lib/libblkid.so"
popd
}

### NFSUTILS ###
_build_nfsutils() {
local VERSION="1.3.2"
local FOLDER="nfs-utils-${VERSION}"
local FILE="${FOLDER}.tar.bz2"
local URL="http://sourceforge.net/projects/nfs/files/nfs-utils/${VERSION}/${FILE}"
local files

_download_bz2 "${FILE}" "${URL}" "${FOLDER}"
pushd "target/${FOLDER}"

# /etc adjustment
files="support/include/nfslib.h utils/mount/configfile.c utils/gssd/gssd.h utils/gssd/svcgssd.c utils/nfsidmap/nfsidmap.c"
for f in $files; do sed -i -e "s|/etc|${DEST}/etc|g" $f; done

# /sbin adjustment
sed -i -e "s|/usr/sbin|$DEST/sbin|g" utils/statd/statd.c
sed -i -e "s|PATH=/sbin:/usr/sbin|PATH=/sbin:/usr/sbin:${DEST}/sbin|g" utils/statd/start-statd

files="utils/osd_login/Makefile.in utils/mount/Makefile.in utils/nfsdcltrack/Makefile.in"
for f in $files; do sed -i -e "s|^sbindir = /sbin|sbindir = ${DEST}/sbin|g" $f; done

# /var adjustment
sed -i -e "s|/var|${DEST}/var|g" utils/mount/nfs4mount.c

files="tests/test-lib.sh utils/statd/statd.man utils/statd/start-statd utils/statd/statd.c"
for f in $files; do sed -i -e "s|/var/run/rpc.statd.pid|/tmp/DroboApps/nfs/rpc.statd.pid|g" $f; done

files="utils/blkmapd/device-discovery.c"
for f in $files; do sed -i -e "s|/var/run/blkmapd.pid|/tmp/DroboApps/nfs/blkmapd.pid|g" $f; done

files="utils/statd/sm-notify.c"
for f in $files; do sed -i -e "s|/var/run/sm-notify.pid|/tmp/DroboApps/nfs/sm-notify.pid|g" $f; done

files="support/include/exportfs.h utils/statd/sm-notify.c utils/idmapd/idmapd.c utils/mount/nfs4mount.c utils/gssd/gssd.h utils/blkmapd/device-discovery.c"
for f in $files; do sed -i -e "s|\"/var/lib|\"${DEST}/var/lib|g" $f; done

PKG_CONFIG_PATH="${DEST}/lib/pkgconfig" ./configure --host="${HOST}" --prefix="${DEST}" --exec-prefix="${DEST}" --sbindir="${DEST}/sbin" --mandir="${DEST}/man" --disable-static --with-statedir="${DEST}/var/lib/nfs" --with-statdpath="${DEST}/var/lib/nfs" --with-statduser=nobody --with-start-statd="${DEST}/sbin/start-statd" --without-systemd --with-mountfile="${DEST}/etc/nfsmounts.conf" --without-tcp-wrappers --enable-tirpc --enable-ipv6 --disable-nfsv4 --disable-nfsv41 --disable-gss CC_FOR_BUILD=$CC LDFLAGS="${LDFLAGS:-} -L${LIBATOMIC}/.libs" LIBS="-llinux-atomic" libblkid_cv_is_recent=yes
make
make install
mkdir -p "${DEST}/etc/exports.d" "${DEST}/var/lib/nfs/statd" "${DEST}/var/lock/subsys" "${DEST}/var/log" "${DEST}/var/run"
rm -vf "${DEST}/sbin/mount.nfs4" "${DEST}/sbin/umount.nfs4"
popd
}

### MODULES ###
_build_module() {
local VERSION="$1"
local FILE="$2"
local URL="https://github.com/droboports/kernel-drobo${DROBO}/releases/download/v${VERSION}/${FILE}"

_download_file_in_folder "${FILE}" "${URL}" "${VERSION}"
mkdir -p "${DEST}/modules/${VERSION}"
cp -vf "download/${VERSION}/${FILE}" "${DEST}/modules/${VERSION}/"
}

_build() {
  _build_atomic
  _build_libtirpc
  _build_rpcbind
  _build_libblkid
  _build_nfsutils
  _build_module 2.6.22.18 exportfs.ko
  _build_module 2.6.22.18 nfsd.ko
  _package
}
