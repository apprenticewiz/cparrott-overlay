# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit flag-o-matic toolchain-funcs

# Oldest fbc known to compile this version (matches freebasic-bootstrap).
BOOTSTRAP_PV="1.10.1"

DESCRIPTION="A free BASIC compiler"
HOMEPAGE="https://www.freebasic.net/"
SRC_URI="
	https://github.com/freebasic/fbc/archive/refs/tags/${PV}.tar.gz
		-> ${P}.tar.gz
"
S="${WORKDIR}/fbc-${PV}"

LICENSE="GPL-2+ LGPL-2.1+"
SLOT="0"
KEYWORDS="~amd64"

# Arch runtime: ncurses. Arch makedepends: freebasic, gpm, libxpm, libxrandr, mesa.
# Those extra libs are linked into user programs via libfb/libfbgfx, so they
# belong in RDEPEND on Gentoo. fbc itself invokes gcc/binutils.
RDEPEND="
	dev-libs/libffi:=
	sys-devel/binutils
	sys-devel/gcc:*
	sys-libs/gpm
	sys-libs/ncurses:=
	virtual/opengl
	x11-libs/libX11
	x11-libs/libXext
	x11-libs/libXpm
	x11-libs/libXrandr
"
DEPEND="${RDEPEND}"
# Same bootstrap || as dev-lang/go: rebuilds use the installed compiler;
# a first install pulls freebasic-bootstrap.
BDEPEND="
	|| (
		>=dev-lang/freebasic-${BOOTSTRAP_PV}
		>=dev-lang/freebasic-bootstrap-${BOOTSTRAP_PV}
	)
	virtual/pkgconfig
"

src_compile() {
	# Arch options=('!lto')
	filter-lto
	append-cflags "$($(tc-getPKG_CONFIG) --cflags libffi)"
	# Command-line CFLAGS replace the makefile's CFLAGS assignment.
	append-cflags -fno-exceptions -fno-unwind-tables -fno-asynchronous-unwind-tables

	local fbc
	if has_version -b ">=dev-lang/freebasic-${BOOTSTRAP_PV}"; then
		fbc="fbc"
	elif has_version -b ">=dev-lang/freebasic-bootstrap-${BOOTSTRAP_PV}"; then
		fbc="${BROOT}/usr/lib/freebasic-bootstrap/bin/fbc"
	else
		die "Need >=dev-lang/freebasic-${BOOTSTRAP_PV} or freebasic-bootstrap"
	fi

	local myemakeargs=(
		CC="$(tc-getCC)"
		AR="$(tc-getAR)"
		AS="$(tc-getAS)"
		CFLAGS="${CFLAGS}"
		FBC="${fbc}"
	)
	# Arch installs into /usr/lib/freebasic even on x86_64. Gentoo wants lib64.
	if [[ $(get_libdir) != lib ]]; then
		myemakeargs+=( ENABLE_LIB64=1 )
	fi

	emake "${myemakeargs[@]}"
}

src_install() {
	local myemakeargs=(
		prefix="${EPREFIX}/usr"
		DESTDIR="${D}"
	)
	if [[ $(get_libdir) != lib ]]; then
		myemakeargs+=( ENABLE_LIB64=1 )
	fi

	emake "${myemakeargs[@]}" install
	doman doc/fbc.1
	dodoc changelog.txt readme.txt
}
