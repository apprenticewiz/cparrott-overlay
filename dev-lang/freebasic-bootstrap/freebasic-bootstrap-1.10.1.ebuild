# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit flag-o-matic toolchain-funcs

# Branch extra-arches-${PV}-bootstrap of apprenticewiz/fbc: upstream's
# ${PV} source-bootstrap release plus linux-riscv64 and linux-loongarch64.
FBC_COMMIT="c1b2b6d7330105c9e5acecc413054cdcf69da2c2"

DESCRIPTION="Bootstrap compiler for FreeBASIC (not for general use)"
HOMEPAGE="https://www.freebasic.net/ https://github.com/freebasic/fbc"
SRC_URI="
	https://github.com/apprenticewiz/fbc/archive/${FBC_COMMIT}.tar.gz
		-> ${P}-${FBC_COMMIT:0:9}.tar.gz
"
S="${WORKDIR}/fbc-${FBC_COMMIT}"

LICENSE="GPL-2+ LGPL-2.1+"
SLOT="0"
# Pre-translated C lives under bootstrap/linux-$(arch); this is not a generic source build.
KEYWORDS="-* ~amd64 ~arm64 ~loong ~riscv"

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
