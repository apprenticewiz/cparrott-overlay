# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8
inherit elisp-common flag-o-matic toolchain-funcs

DESCRIPTION="GNU Common Lisp"
HOMEPAGE="https://www.gnu.org/software/gcl/gcl.html"
SRC_URI="http://git.savannah.gnu.org/cgit/gcl.git/snapshot/${PN}-Version_2_6_15pre3.tar.gz
	https://dev.gentoo.org/~grozin/${PN}-2.6.15_pre3-spelling.patch.gz"
S="${WORKDIR}"/${PN}-Version_2_6_15pre3/${PN}

LICENSE="LGPL-2+ GPL-2+"
SLOT="0"
KEYWORDS="~amd64 ~arm ~ppc ~ppc64 ~riscv ~x86"
IUSE="+ansi athena doc emacs +readline tk X"
RESTRICT="strip"  #205803

RDEPEND="dev-libs/gmp
	virtual/latex-base
	emacs? ( app-editors/emacs:= )
	readline? ( sys-libs/readline:= )
	athena? ( x11-libs/libXaw )
	tk? ( dev-lang/tk:= )
	X? ( x11-libs/libXt x11-libs/libXext x11-libs/libXmu x11-libs/libXaw )"
DEPEND="${RDEPEND}
	virtual/texi2dvi
	app-text/texi2html
	>=dev-build/autoconf-2.52"

PATCHES=(
	"${WORKDIR}"/${PN}-2.6.15_pre3-spelling.patch
	# bug 893938
	"${FILESDIR}"/${PN}-2.6.15-riscv.patch
	"${FILESDIR}"/${PN}-2.6.15-glibc-2.43-bsearch.patch
)

src_configure() {
	filter-lto # bug #931082
	strip-flags
	append-cflags -std=gnu17 # bug #947758
	append-cppflags -std=gnu17 # ditto
	filter-flags -fstack-protector -fstack-protector-all

	# GCL loads runtime-compiled .o files with its own ELF loader, which binds
	# undefined libc symbols (_setjmp, __stack_chk_fail, ...) to the lazy .plt
	# stubs it finds in the dumped image's symbol table. Under -z now those
	# stubs are dead code: ld.so never fills the resolver slot of the GOT, so
	# the first such call jumps to address 0 and PCL dies with
	# "Caught fatal error [memory may be damaged]" on gcl_pcl_defclass.lisp.
	append-ldflags $(test-flags-CCLD -Wl,-z,lazy)

	local tcl=""
	if use tk; then
		tcl="--enable-tclconfig=/usr/lib --enable-tkconfig=/usr/lib"
	fi

	econf --enable-dynsysgmp \
		--disable-xdr \
		--enable-emacsdir=/usr/share/emacs/site-lisp/gcl \
		$(use_enable readline) \
		$(use_enable ansi) \
		$(use_enable athena xgcl) \
		$(use_with X x) \
		${tcl}
}

src_compile() {
	# The rules for the bin/ helper programs (dpp, merge, file-sub, append)
	# use ${CC} ${DEFS} without ${CFLAGS}, so the -std=gnu17 workaround has
	# to ride along in CC. Otherwise gcc >= 15 compiles them as C23, where
	# dpp.c's "typedef int bool" is an error.
	emake -j1 CC="$(tc-getCC) -std=gnu17"
}

src_test() {
	local make_ansi_tests_clean="rm -f test.out *.fasl *.o *.so *~ *.fn *.x86f *.fasl *.ufsl"
	if use ansi; then
		cd ansi-tests

		( make clean && make test-unixport ) \
			|| die "make ansi-tests failed!"

		cat "${FILESDIR}/bootstrap-gcl" \
			| ../unixport/saved_ansi_gcl

		cat "${FILESDIR}/bootstrap-gcl" \
			|sed s/bootstrapped_ansi_gcl/bootstrapped_r_ansi_gcl/g \
			| ./bootstrapped_ansi_gcl

		( ${make_ansi_tests_clean} && \
			echo "(load \"gclload.lsp\")" \
			| ./bootstrapped_r_ansi_gcl ) \
			|| die "Phase 2, bootstraped compiler failed in tests"
	fi
}

src_install() {
	emake DESTDIR="${D}" install
	dodoc readme readme.gmp readme.xgcl ChangeLog doc/*

	pushd "${D}"/usr/share/doc > /dev/null
	rm dwdoc.tex || die "rm dwdoc.tex.bz2 failed"
	if use doc; then
		mv *.pdf gcl gcl-si gcl-tk dwdoc ${PF} || die "mv * ${PF} failed"
	else
		rm -rf *.pdf gcl gcl-si gcl-tk dwdoc
	fi
	popd > /dev/null

	if use emacs; then
		elisp-site-file-install "${FILESDIR}"/64${PN}-gentoo.el
		elisp-install ${PN} elisp/*.el
	fi
}

pkg_postinst() {
	use emacs && elisp-site-regen
}

pkg_postrm() {
	use emacs && elisp-site-regen
}
