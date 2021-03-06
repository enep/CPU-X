#!/bin/bash
# This script helps to track build troubles and make portable versions

VER=$(git tag | tail -n1)
SRCDIR=/tmp/CPU-X
DESTDIR="$(dirname $0)/portable"
JOBS=-j2
VMs=("Arch32"  "Arch64"  "BSD32" "BSD64")
EXT=("linux32" "linux64" "bsd32" "bsd64")


#########################################################
#			FUNCTIONS			#
#########################################################

wait_for_vm_up() {
	while ! $(ssh -q $1 exit); do
		sleep 1
	done
}

check_deps() {
	if [[ "$1" == "Arch"* ]]; then
		LIBS="/usr/lib/{libncursesw.a,libcurl.a,libssl.a,libcrypto.a,libarchive.a,libcpuid.a,libpci.a,libprocps.a}"
		wait_for_vm_up $1
		if ! ssh $1 ls $LIBS > /dev/null; then
			exit 255
		fi
	fi
}

make_build() {
	wait_for_vm_up $1
	ssh $1 << EOF
_makeopts() {
	if make $JOBS; then
		echo -e "\n\t\033[1;42m*** Build passed for $1 ***\033[0m\n\n"
		sleep 2
	else
		echo -e "\n\t\033[1;41m*** Build failed for $1 ***\033[0m\n\n"
		sleep 10
	fi
}

[[ ! -d $SRCDIR ]] && git clone https://github.com/X0rg/CPU-X $SRCDIR || (cd $SRCDIR && git pull)
mkdir -pv $SRCDIR/{,e}build{1..9}

echo -e "\n\n\033[1;44m*** Start normal build for $1\033[0m\n"
cd $SRCDIR/build1 && cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=/usr                    .. && _makeopts
cd $SRCDIR/build2 && cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=/usr -DWITH_GTK=0       .. && _makeopts
cd $SRCDIR/build3 && cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=/usr -DWITH_NCURSES=0   .. && _makeopts
cd $SRCDIR/build4 && cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=/usr -DWITH_GETTEXT=0   .. && _makeopts
cd $SRCDIR/build5 && cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=/usr -DWITH_LIBCPUID=0  .. && _makeopts
cd $SRCDIR/build6 && cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=/usr -DWITH_LIBPCI=0    .. && _makeopts
cd $SRCDIR/build7 && cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=/usr -DWITH_LIBPROCPS=0 -DWITH_LIBSTATGRAB=0 .. && _makeopts
cd $SRCDIR/build8 && cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=/usr -DWITH_DMIDECODE=0 .. && _makeopts
cd $SRCDIR/build9 && cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=/usr -DWITH_BANDWIDTH=0 .. && _makeopts

sleep 5
echo -e "\n\n\033[1;44m*** Start portable build for $1\033[0m\n"
cd $SRCDIR/ebuild1 && cmake -DCMAKE_BUILD_TYPE=Debug -DPORTABLE_BINARY=1                    .. && _makeopts
cd $SRCDIR/ebuild2 && cmake -DCMAKE_BUILD_TYPE=Debug -DPORTABLE_BINARY=1 -DWITH_GTK=0       .. && _makeopts
cd $SRCDIR/ebuild3 && cmake -DCMAKE_BUILD_TYPE=Debug -DPORTABLE_BINARY=1 -DWITH_NCURSES=0   .. && _makeopts
cd $SRCDIR/ebuild4 && cmake -DCMAKE_BUILD_TYPE=Debug -DPORTABLE_BINARY=1 -DWITH_GETTEXT=0   .. && _makeopts
cd $SRCDIR/ebuild5 && cmake -DCMAKE_BUILD_TYPE=Debug -DPORTABLE_BINARY=1 -DWITH_LIBCPUID=0  .. && _makeopts
cd $SRCDIR/ebuild6 && cmake -DCMAKE_BUILD_TYPE=Debug -DPORTABLE_BINARY=1 -DWITH_LIBPCI=0    .. && _makeopts
cd $SRCDIR/ebuild7 && cmake -DCMAKE_BUILD_TYPE=Debug -DPORTABLE_BINARY=1 -DWITH_LIBPROCPS=0 -DWITH_LIBSTATGRAB=0 .. && _makeopts
cd $SRCDIR/ebuild8 && cmake -DCMAKE_BUILD_TYPE=Debug -DPORTABLE_BINARY=1 -DWITH_DMIDECODE=0 .. && _makeopts
cd $SRCDIR/ebuild9 && cmake -DCMAKE_BUILD_TYPE=Debug -DPORTABLE_BINARY=1 -DWITH_BANDWIDTH=0 .. && _makeopts
EOF
}

make_release() {
	wait_for_vm_up $1
	ssh $1 << EOF
_makeopts() {
	if make $JOBS > /dev/null ; then
		echo -e "\n\t\033[1;42m*** Build passed for $1 ***\033[0m\n\n"
	else
		echo -e "\n\t\033[1;41m*** Build failed for $1 ***\033[0m\n\n"
		exit
	fi
}

[[ ! -d $SRCDIR ]] && git clone https://github.com/X0rg/CPU-X $SRCDIR || (cd $SRCDIR && git pull)
mkdir -pv $SRCDIR/{,g}n_build

cd $SRCDIR/gn_build && cmake -DCMAKE_BUILD_TYPE=Release -DPORTABLE_BINARY=1              .. > /dev/null && _makeopts
cd $SRCDIR/n_build  && cmake -DCMAKE_BUILD_TYPE=Release -DPORTABLE_BINARY=1 -DWITH_GTK=0 .. > /dev/null && _makeopts
EOF
}

make_packages() {
	GPKG="wget -q --show-progress -c"
	REPO="http://download.opensuse.org/repositories/home:/X0rg"
	DISTRO="$1"
	PKG1="$2"
	PKG2="$3"
	PKG3="$4"

	case $DISTRO in
		Arch*)             BIT32="i686"; BIT64="x86_64"; EXT="pkg.tar.xz";;
		Debian*|xUbuntu*)  BIT32="i386"; BIT64="amd64" ; EXT="deb";;
		Fedora*)           BIT32="i686"; BIT64="x86_64"; EXT="rpm";;
		openSUSE*)         BIT32="i586"; BIT64="x86_64"; EXT="rpm";;
	esac

	for arch in "$BIT32" "$BIT64"; do
		mkdir -p "$DISTRO/$arch" && cd "$DISTRO/$arch"
		for pkg in "$PKG1" "$PKG2" "$PKG3"; do
			$GPKG "$REPO/$DISTRO/$arch/$pkg$arch.$EXT"
		done
		cd ../..
	done
}

stop_vms() {
	echo "Shutdown VMs (y/N)?"
	read -n1 s

	if [[ $s == "y" ]]; then
		for i in {0..3}; do
			ssh ${VMs[i]} sudo poweroff
		done
	fi
}

help() {
	echo -e "Usage: $0 OPTION"
	echo -e "Options:"
	echo -e "\t-b, --build\tStart multiples builds to find build troubles"
	echo -e "\t-r, --release\tBuild portable versions when a new version is tagged"
	echo -e "\t-p, --package\tMake tarballs which contain packages"
	echo -e "\t-s, --shutdown\tStop all virtual machines"
	echo -e "\t-h, --help\tDisplay this help and exit"
}


#########################################################
#			MAIN				#
#########################################################

if [[ $# < 1 ]]; then
	help
	exit 1
fi

case "$1" in
	-b|--build)	choice="build";;
	-r|--release)	choice="release";;
	-p|--package)   choice="package";;
	-s|--shutdown)  stop_vms; exit 0;;
	-h|--help)	help; exit 0;;
	- |--)		help; exit 1;;
	*)		help; exit 1;;
esac

case "$choice" in
	build)
		# Start VMs
		VBoxManage list runningvms | grep -q "Arch Linux i686"   || (echo "Start 32-bit Linux VM" ; VBoxHeadless --startvm "Arch Linux i686" &)
		VBoxManage list runningvms | grep -q "GhostBSD i386"     || (echo "Start 32-bit BSD VM"   ; VBoxHeadless --startvm "GhostBSD i386" &)
		sleep 1

		# Start build
		check_deps Arch32
		make_build Arch32
		echo "Press a key to continue..." ; read
		make_build BSD32

		stop_vms
		;;

	release)
		# Start VMs
		VBoxManage list runningvms | grep -q "Arch Linux i686"   || (echo "Start 32-bit Linux VM" ; VBoxHeadless --startvm "Arch Linux i686" &)
		VBoxManage list runningvms | grep -q "Arch Linux x86_64" || (echo "Start 64-bit Linux VM" ; VBoxHeadless --startvm "Arch Linux x86_64" &)
		VBoxManage list runningvms | grep -q "GhostBSD i386"     || (echo "Start 32-bit BSD VM"   ; VBoxHeadless --startvm "GhostBSD i386" &)
		VBoxManage list runningvms | grep -q "GhostBSD x86_64"   || (echo "Start 64-bit BSD VM"   ; VBoxHeadless --startvm "GhostBSD x86_64" &)
		sleep 1

		# Start build
		[[ -d "$DESTDIR" ]] && rm -rf "$DESTDIR"
		mkdir -pv "$DESTDIR/sshfs"
		for i in {0..3}; do
			check_deps ${VMs[i]}
			make_release ${VMs[i]}
			sshfs ${VMs[i]}:$SRCDIR "$DESTDIR/sshfs"
			cp -v "$DESTDIR/sshfs/gn_build/cpu-x" "$DESTDIR/CPU-X_${VER}_portable.${EXT[i]}"
			cp -v "$DESTDIR/sshfs/n_build/cpu-x"  "$DESTDIR/CPU-X_${VER}_portable_noGTK.${EXT[i]}"
			fusermount -u "$DESTDIR/sshfs"
		done

		# Make tarball
		cd "$DESTDIR"
		tar -zcvf CPU-X_${VER}_portable.tar.gz       CPU-X_${VER}_portable.*
		tar -zcvf CPU-X_${VER}_portable_noGTK.tar.gz CPU-X_${VER}_portable_noGTK.*

		stop_vms
		;;

	package)
		DESTDIR="$(dirname $0)/packages/"
		PKGNAME="cpu-x"
		CPUXVER="${VER//v}"
		CPUXREV=$(wget -qO- http://download.opensuse.org/repositories/home:/X0rg/Fedora_24/x86_64/ | grep $PKGNAME-$CPUXVER | awk -v FS="($PKGNAME-$CPUXVER-|.x86_64.rpm)" '{print $2}')
		LCPUIDNAME="libcpuid"
		LCPUIDABI="14"
		LCPUIDVER=$(cd `dirname $0`/../libcpuid && git describe --long --tags | sed 's/^v//;s/\([^-]*-g\)/r\1/;s/-/./g')
		LCPUIDREV=$(wget -qO- http://download.opensuse.org/repositories/home:/X0rg/Fedora_24/x86_64/ | grep $LCPUIDNAME$LCPUIDABI-$LCPUIDVER | awk -v FS="($LCPUIDNAME$LCPUIDABI-$LCPUIDVER-|.x86_64.rpm)" '{print $2}')
		COMPRESS="tar -zcvf"
		mkdir -p "$DESTDIR" && cd "$DESTDIR"

		# Arch Linux
		make_packages "Arch_Extra" "${PKGNAME}-${CPUXVER}-1-" "${LCPUIDNAME}-git-2:${LCPUIDVER}-1-"
		$COMPRESS CPU-X_${VER}_ArchLinux.tar.gz Arch*

		# Debian
		make_packages "Debian_8.0" "${PKGNAME}_${CPUXVER}_" "${LCPUIDNAME}${LCPUIDABI}_${LCPUIDVER}_" "${LCPUIDNAME}${LCPUIDABI}-dev_${LCPUIDVER}_"
		make_packages "Debian_9.0" "${PKGNAME}_${CPUXVER}_" "${LCPUIDNAME}${LCPUIDABI}_${LCPUIDVER}_" "${LCPUIDNAME}${LCPUIDABI}-dev_${LCPUIDVER}_"
		$COMPRESS CPU-X_${VER}_Debian.tar.gz Debian*

		# Fedora
		make_packages "Fedora_21" "${PKGNAME}-${CPUXVER}-${CPUXREV}." "${LCPUIDNAME}${LCPUIDABI}-${LCPUIDVER}-${LCPUIDREV}." "${LCPUIDNAME}-devel-${LCPUIDVER}-${LCPUIDREV}."
		make_packages "Fedora_22" "${PKGNAME}-${CPUXVER}-${CPUXREV}." "${LCPUIDNAME}${LCPUIDABI}-${LCPUIDVER}-${LCPUIDREV}." "${LCPUIDNAME}-devel-${LCPUIDVER}-${LCPUIDREV}."
		make_packages "Fedora_23" "${PKGNAME}-${CPUXVER}-${CPUXREV}." "${LCPUIDNAME}${LCPUIDABI}-${LCPUIDVER}-${LCPUIDREV}." "${LCPUIDNAME}-devel-${LCPUIDVER}-${LCPUIDREV}."
		make_packages "Fedora_24" "${PKGNAME}-${CPUXVER}-${CPUXREV}." "${LCPUIDNAME}${LCPUIDABI}-${LCPUIDVER}-${LCPUIDREV}." "${LCPUIDNAME}-devel-${LCPUIDVER}-${LCPUIDREV}."
		$COMPRESS CPU-X_${VER}_Fedora.tar.gz Fedora*

		# openSUSE
		make_packages "openSUSE_13.1"       "${PKGNAME}-${CPUXVER}-${CPUXREV}." "${LCPUIDNAME}${LCPUIDABI}-${LCPUIDVER}-${LCPUIDREV}." "${LCPUIDNAME}-devel-${LCPUIDVER}-${LCPUIDREV}."
		make_packages "openSUSE_13.2"       "${PKGNAME}-${CPUXVER}-${CPUXREV}." "${LCPUIDNAME}${LCPUIDABI}-${LCPUIDVER}-${LCPUIDREV}." "${LCPUIDNAME}-devel-${LCPUIDVER}-${LCPUIDREV}."
		make_packages "openSUSE_Leap_42.1"  "${PKGNAME}-${CPUXVER}-${CPUXREV}." "${LCPUIDNAME}${LCPUIDABI}-${LCPUIDVER}-${LCPUIDREV}." "${LCPUIDNAME}-devel-${LCPUIDVER}-${LCPUIDREV}."
		make_packages "openSUSE_Leap_42.2"  "${PKGNAME}-${CPUXVER}-${CPUXREV}." "${LCPUIDNAME}${LCPUIDABI}-${LCPUIDVER}-${LCPUIDREV}." "${LCPUIDNAME}-devel-${LCPUIDVER}-${LCPUIDREV}."
		make_packages "openSUSE_Tumbleweed" "${PKGNAME}-${CPUXVER}-${CPUXREV}." "${LCPUIDNAME}${LCPUIDABI}-${LCPUIDVER}-${LCPUIDREV}." "${LCPUIDNAME}-devel-${LCPUIDVER}-${LCPUIDREV}."
		find . -type d -empty -exec rmdir {} \;
		$COMPRESS CPU-X_${VER}_openSUSE.tar.gz openSUSE*

		# Ubuntu
		make_packages "xUbuntu_14.04" "${PKGNAME}_${CPUXVER}_" "${LCPUIDNAME}${LCPUIDABI}_${LCPUIDVER}_" "${LCPUIDNAME}${LCPUIDABI}-dev_${LCPUIDVER}_"
		make_packages "xUbuntu_15.04" "${PKGNAME}_${CPUXVER}_" "${LCPUIDNAME}${LCPUIDABI}_${LCPUIDVER}_" "${LCPUIDNAME}${LCPUIDABI}-dev_${LCPUIDVER}_"
		make_packages "xUbuntu_15.10" "${PKGNAME}_${CPUXVER}_" "${LCPUIDNAME}${LCPUIDABI}_${LCPUIDVER}_" "${LCPUIDNAME}${LCPUIDABI}-dev_${LCPUIDVER}_"
		make_packages "xUbuntu_16.04" "${PKGNAME}_${CPUXVER}_" "${LCPUIDNAME}${LCPUIDABI}_${LCPUIDVER}_" "${LCPUIDNAME}${LCPUIDABI}-dev_${LCPUIDVER}_"
		make_packages "xUbuntu_16.10" "${PKGNAME}_${CPUXVER}_" "${LCPUIDNAME}${LCPUIDABI}_${LCPUIDVER}_" "${LCPUIDNAME}${LCPUIDABI}-dev_${LCPUIDVER}_"
		$COMPRESS CPU-X_${VER}_Ubuntu.tar.gz xUbuntu*
		;;
esac
