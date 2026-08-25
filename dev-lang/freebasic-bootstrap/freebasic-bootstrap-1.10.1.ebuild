# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit flag-o-matic toolchain-funcs

DESCRIPTION="Bootstrap compiler for FreeBASIC (not for general use)"
HOMEPAGE="https://www.freebasic.net/"
SRC_URI="https://github.com/freebasic/fbc/releases/download/${PV}/FreeBASIC-${PV}-source-bootstrap.tar.xz"
S="${WORKDIR}/FreeBASIC-${PV}-source-bootstrap"

LICENSE="GPL-2+ LGPL-2.1+"
SLOT="0"
# Pre-translated C lives under bootstrap/linux-$(arch); this is not a generic source build.
KEYWORDS="-* ~amd64"

RDEPEND="sys-libs/ncurses:="
DEPEND="${RDEPEND}"

# fbc with no ENABLE_PREFIX resolves its own prefix as $(dirname $(exepath))/..,
# then looks for <prefix>/lib/freebasic/<target> and <prefix>/include/freebasic.
# Install a self-contained prefix so those lookups succeed without wrappers.
BOOTSTRAP_PREFIX="/usr/lib/${PN}"

# Features the bootstrap fbc does not need in order to link another fbc.
# The makefile only adds these itself for the bootstrap-minimal goal.
BOOTSTRAP_CFLAGS="-DDISABLE_GPM -DDISABLE_FFI -DDISABLE_X11"

src_compile() {
	filter-lto
	# Command-line CFLAGS replace the makefile's CFLAGS assignment.
	append-cflags -fno-exceptions -fno-unwind-tables -fno-asynchronous-unwind-tables

	# bootstrap-minimal disables gpm/ffi/X11; only ncurses is needed to link fbc.
	# Gentoo splits tinfo out of ncurses.
	emake bootstrap-minimal \
		CC="$(tc-getCC)" \
		AR="$(tc-getAR)" \
		AS="$(tc-getAS)" \
		CFLAGS="${CFLAGS}" \
		BOOTSTRAP_LIBS="-lncurses -ltinfo -lm -pthread"
}

src_install() {
	# install-compiler would relink fbc from BASIC sources, which the
	# pre-translated bootstrap tree cannot do. Install the binary directly.
	# Everything else uses upstream's layout so fbc finds it on its own.
	emake install-includes install-rtlib \
		prefix="${EPREFIX}${BOOTSTRAP_PREFIX}" \
		DESTDIR="${D}" \
		CFLAGS="${CFLAGS} ${BOOTSTRAP_CFLAGS}"

	# Keep this off PATH (same idea as ada-bootstrap and go-bootstrap).
	exeinto "${BOOTSTRAP_PREFIX}"/bin
	doexe bin/fbc
}

pkg_postinst() {
	elog "${PN} is only for building dev-lang/freebasic."
	elog "It lives under ${EPREFIX}${BOOTSTRAP_PREFIX} and is not on PATH."
	elog "After freebasic is installed you can depclean this package."
}
