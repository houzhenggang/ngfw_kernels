# Our version number.  Reset to untangle1 when going upstream.
# Currently must be manually updated.  You've been warned.
OURVERSION=untangle2

# Upstream version numbers
KVER=2.6.24
KDEBVER=16

KUPVER=${KDEBVER}.30
PACKPFX=linux_${KVER}
WORKDIR=linux-${KVER}
KDSC=${PACKPFX}-${KUPVER}.dsc
KOURPATCH=untangle-linux.diff.gz

UMUPVER=${KDEBVER}.23
UMPFX=linux-ubuntu-modules-${KVER}_${KVER}
UMWORKDIR=linux-ubuntu-modules-${KVER}-${KVER}
UMDSC=${UMPFX}-${UMUPVER}.dsc
UMOURPATCH=untangle-linux-ubuntu-modules.diff.gz

RMVER=12
RMUPVER=${KDEBVER}.34
RMPFX=linux-restricted-modules-${KVER}_${KVER}.${RMVER}
RMWORKDIR=linux-restricted-modules-${KVER}-${KVER}.${RMVER}
RMDSC=${RMPFX}-${RMUPVER}.dsc
RMOURPATCH=untangle-linux-restricted-modules.diff.gz

METAUPVER=${KDEBVER}.18
METAPFX=linux-meta_${KVER}
METAWORKDIR=linux-meta-${KVER}.${METAUPVER}
METADSC=${METAPFX}.${METAUPVER}.dsc
METAOURPATCH=untangle-linux-meta.diff.gz

EXTRAPATCHES ?=
EXTRADCHARGS ?=

DOPTIONS=DEB_BUILD_OPTIONS="parallel=${NPROCEXP}" AUTOBUILD=1 KVERS=${KVER}-${KDEBVER}-untangle
VDOPTIONS=DEB_BUILD_OPTIONS="parallel=${NPROCEXP}" AUTOBUILD=1 KVERS=${KVER}-${KDEBVER}-virtual-untangle

MACHINE:=$(shell if [ `uname -m` = "x86_64" ]; then echo "amd64"; else echo "i386"; fi)
NPROCEXP:=$(shell echo "$$((1+`grep processor /proc/cpuinfo|wc -l`))")
TEMPDIR:=$(shell mktemp)


all:	clean pkgs legitify

pkgs::	kpkg umpkg

deps:	force
	sudo apt-get install ${BUILDDEPS} || echo "unable to run sudo"

kpkg:	${WORKDIR} force
	cd ${WORKDIR}; ${DOPTIONS} fakeroot debian/rules clean custom-binary-untangle
ifneq ($(MACHINE),amd64)
	cd ${WORKDIR}; ${VDOPTIONS} fakeroot debian/rules custom-binary-virtual-untangle
endif
	cd ${WORKDIR}; ${DOPTIONS} fakeroot debian/rules binary-indep binary-arch-headers

umpkg:	${UMWORKDIR} force
# A blunt instrument:
	sudo dpkg -i linux-headers-${KVER}-${KDEBVER}_${KVER}-${KUPVER}${OURVERSION}_all.deb linux-headers-${KVER}-${KDEBVER}-untangle_${KVER}-${KUPVER}${OURVERSION}_${MACHINE}.deb
	sudo rm -f /usr/src/linux-headers-untangle;sudo ln -s /usr/src/linux-headers-${KVER}-${KDEBVER}-untangle /usr/src/linux-headers-untangle
	cd ${UMWORKDIR}; ${DOPTIONS} fakeroot debian/rules clean binary-debs arch=${MACHINE} flavours="untangle"
ifneq ($(MACHINE),amd64)
	sudo dpkg -i linux-headers-${KVER}-${KDEBVER}-virtual-untangle_${KVER}-${KUPVER}${OURVERSION}_${MACHINE}.deb
	sudo rm -f /usr/src/linux-headers-virtual-untangle;sudo ln -s /usr/src/linux-headers-${KVER}-${KDEBVER}-virtual-untangle /usr/src/linux-headers-virtual-untangle
	cd ${UMWORKDIR}; ${VDOPTIONS} fakeroot debian/rules clean binary-debs arch=${MACHINE} flavours="virtual-untangle"
endif

rmpkg:	${RMWORKDIR} force
# Need something better than this.
	sudo dpkg -i linux-headers-${KVER}-${KDEBVER}_${KVER}-${KUPVER}${OURVERSION}_all.deb linux-headers-${KVER}-${KDEBVER}-untangle_${KVER}-${KUPVER}${OURVERSION}_${MACHINE}.deb
	sudo rm -f /usr/src/linux-headers-untangle;sudo ln -s /usr/src/linux-headers-${KVER}-${KDEBVER}-untangle /usr/src/linux-headers-untangle
	cd ${RMWORKDIR}; ${DOPTIONS} fakeroot debian/rules clean binary-debs arch=${MACHINE} flavours="${KVER}-${KDEBVER}-untangle" ati_flavours="${KVER}-${KDEBVER}-untangle" nv_flavours="${KVER}-${KDEBVER}-untangle"
	cd ${RMWORKDIR}; ${DOPTIONS} fakeroot debian/rules binary-indep arch=${MACHINE} flavours="${KVER}-${KDEBVER}-untangle" ati_flavours="${KVER}-${KDEBVER}-untangle" nv_flavours="${KVER}-${KDEBVER}-untangle"

metapkg:	${METAWORKDIR} force
	cd ${METAWORKDIR}; ${DOPTIONS} fakeroot debian/rules clean binary arch=${MACHINE} flavours="untangle"
ifneq ($(MACHINE),amd64)
	cd ${METAWORKDIR}; ${VDOPTIONS} fakeroot debian/rules clean binary arch=${MACHINE} flavours="virtual-untangle"
endif


# This combines our generic kernel patches with the specific Ubuntu kernel
# patches into one patch to rule them all.
UPATCHSETLOC=${WORKDIR}/debian/binary-custom.d/untangle/patchset
UVPATCHSETLOC=${WORKDIR}/debian/binary-custom.d/virtual-untangle/patchset
${KOURPATCH}: untangle-linux.basediff patches/0*
	rm -rf ${TEMPDIR}
	mkdir -p ${TEMPDIR}/${UPATCHSETLOC}
	mkdir -p ${TEMPDIR}/old/${UPATCHSETLOC}
	cp patches/0* ${TEMPDIR}/${UPATCHSETLOC}
	if [ -n "${EXTRAPATCHES}" ]; then cp "${EXTRAPATCHES}" ${TEMPDIR}/${UPATCHSETLOC}; fi
	-cd ${TEMPDIR};diff -Ncr old/${UPATCHSETLOC} ${UPATCHSETLOC} > ${TEMPDIR}/all.diff
	mkdir -p ${TEMPDIR}/${UVPATCHSETLOC}
	mkdir -p ${TEMPDIR}/old/${UVPATCHSETLOC}
	cp patches/0* ${TEMPDIR}/${UVPATCHSETLOC}
	if [ -n "${EXTRAPATCHES}" ]; then cp "${EXTRAPATCHES}" ${TEMPDIR}/${UVPATCHSETLOC}; fi
	-cd ${TEMPDIR};diff -Ncr old/${UVPATCHSETLOC} ${UVPATCHSETLOC} >> ${TEMPDIR}/all.diff
	cat untangle-linux.basediff >> ${TEMPDIR}/all.diff
	if [ -f untangle-linux.${REPOSITORY}diff ]; then cat untangle-linux.${REPOSITORY}diff >> ${TEMPDIR}/all.diff; fi
	gzip -c ${TEMPDIR}/all.diff > ${KOURPATCH}

${WORKDIR}:	${KDSC} ${KOURPATCH}
	rm -rf ${WORKDIR}
	dpkg-source -x ${KDSC}
	cd ${WORKDIR};gunzip -c ../${KOURPATCH} | patch -p1
# Clean out control.stub so that it always gets generated.
	rm ${WORKDIR}/debian/control.stub
	cd ${WORKDIR}; DEBEMAIL="jdi@untangle.com" dch ${EXTRADCHARGS} -p -v ${KVER}-${KUPVER}${OURVERSION} "kernel build"

${UMWORKDIR}:	${UMDSC} ${UMOURPATCH}
	rm -rf ${UMWORKDIR}
	dpkg-source -x ${UMDSC}
	cd ${UMWORKDIR};gunzip -c ../${UMOURPATCH} | patch -p1
	cd ${UMWORKDIR}; DEBEMAIL="jdi@untangle.com" dch ${EXTRADCHARGS} -p -v ${KVER}-${UMUPVER}${OURVERSION} "kernel build"

${RMWORKDIR}:	${RMDSC} ${RMOURPATCH}
	rm -rf ${RMWORKDIR}
	dpkg-source -x ${RMDSC}
	cd ${RMWORKDIR};gunzip -c ../${RMOURPATCH} | patch -p1
	cd ${RMWORKDIR}; DEBEMAIL="jdi@untangle.com" dch ${EXTRADCHARGS} -p -v ${KVER}.${RMVER}-${RMUPVER}${OURVERSION} "kernel build"

${METAWORKDIR}:	${METADSC} ${METAOURPATCH}
	rm -rf ${METAWORKDIR}
	dpkg-source -x ${METADSC}
	cd ${METAWORKDIR};gunzip -c ../${METAOURPATCH} | patch -p1
	cd ${METAWORKDIR}; DEBEMAIL="jdi@untangle.com" dch ${EXTRADCHARGS} -p -v ${KVER}.${METAUPVER}${OURVERSION} "kernel build"

clean::
	rm -f ${KOURPATCH}
	rm -rf ${WORKDIR}
	rm -rf ${UMWORKDIR}
	rm -rf ${RMWORKDIR}
	rm -rf ${METAWORKDIR}
	rm -rf notlegit
	rm -f *.deb modules/*.deb
	rm -f *.udeb modules/*.udeb

force: