# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Binary DMD + Phobos used to bootstrap dev-lang/dmd (not for general use)"
HOMEPAGE="https://dlang.org/"
SRC_URI="dmd-bootstrap-${PV}-amd64.tar.xz"
S="${WORKDIR}/dmd-bootstrap-${PV}"

LICENSE="Boost-1.0"
SLOT="0"
KEYWORDS="-* ~amd64"

# Built from source with gdc by scripts/dmd-bootstrap-tarball.sh in this
# overlay; there is no upstream distfile to fetch. The tarball is not
# byte-reproducible, so re-run 'ebuild --force ... manifest' after building
# a new one.
RESTRICT="fetch strip"

RDEPEND="
	>=sys-devel/gcc-9
	net-misc/curl
"

QA_PREBUILT="
	usr/lib/${PN}/bin/dmd
	usr/lib/${PN}/lib/libphobos2.so*
"

src_install() {
	local dest="/usr/lib/${PN}"

	exeinto "${dest}/bin"
	doexe bin/dmd

	insinto "${dest}/include"
	doins -r include/dlang

	# Preserve SONAME symlinks; doins would flatten them.
	local dest_lib="${ED}${dest}/lib"
	mkdir -p "${dest_lib}" || die
	cp -P lib/libdruntime.a lib/libphobos2.a lib/libphobos2.so* "${dest_lib}/" || die
	chmod 0644 "${dest_lib}"/*.a || die
	chmod 0755 "${dest_lib}"/*.so* || die

	# dmd searches for dmd.conf next to the executable.
	local inc="${EPREFIX}${dest}/include/dlang/dmd"
	local lib="${EPREFIX}${dest}/lib"
	local dflags="-I${inc} -L-L${lib} -L--export-dynamic -fPIC"
	printf '%s\n' '[Environment64]' "DFLAGS=${dflags}" > "${T}/dmd.conf" || die
	insinto "${dest}/bin"
	doins "${T}/dmd.conf"
}

pkg_nofetch() {
	eerror "Place ${A} for your architecture in \${DISTDIR}."
	eerror "The overlay's scripts/dmd-bootstrap-tarball.sh builds one from"
	eerror "source using gdc from sys-devel/gcc[d]."
}

pkg_postinst() {
	elog "${PN} is only for building dev-lang/dmd and dev-libs/libphobos."
	elog "It lives under ${EPREFIX}/usr/lib/${PN} and is not on PATH."
	elog "Once dev-lang/dmd is installed it becomes the host compiler for"
	elog "both packages, so this one can be removed with emerge --depclean."
}
