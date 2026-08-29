# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# 4.2.0's configure allows LLVM 7.1 through 20.1 (plus a few point
# releases). llvm-r2 drops slots older than 17; 21 is not on the list.
LLVM_COMPAT=( {17..20} )

inherit llvm-r2

DESCRIPTION="Standard ML compiler with C interop, SQL, and native threads"
HOMEPAGE="https://smlsharp.github.io/"
SRC_URI="https://github.com/smlsharp/smlsharp/releases/download/v${PV}/${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="test"
RESTRICT="!test? ( test )"

# AUR smlsharp 4.2.0-1: official tarball, ./configure --prefix=/usr,
# optional two-stage bootstrap left off, chrpath -d on the compiler,
# keep runtime archives. LLVM tools (llc, opt, llvm-as, llvm-dis) are
# used both while building the compiler and when compiling user code.
RDEPEND="
	dev-libs/gmp:=
	dev-libs/massivethreads:=
	$(llvm_gen_dep '
		llvm-core/llvm:${LLVM_SLOT}=
	')
"
DEPEND="${RDEPEND}"
BDEPEND="
	app-admin/chrpath
	$(llvm_gen_dep '
		llvm-core/llvm:${LLVM_SLOT}=
	')
"

PATCHES=(
	"${FILESDIR}/${P}-remove-tz-test.patch"
)

pkg_setup() {
	llvm-r2_pkg_setup
}

src_configure() {
	econf --with-llvm="$(get_llvm_prefix)"
}

src_test() {
	emake test
}

src_install() {
	# AUR: the compiler binary carries a build-dir rpath.
	chrpath -d src/compiler/smlsharp || die

	emake DESTDIR="${D}" install
	einstalldocs
	newdoc src/smlnj/LICENSE SMLNJ_LICENSE
}

pkg_postinst() {
	elog "SML# links programs with MassiveThreads. Single-core is the"
	elog "default; set MYTH_NUM_WORKERS (0 means all cores on Linux) to"
	elog "use more than one CPU:"
	elog ""
	elog "    MYTH_NUM_WORKERS=0 smlsharp"
}
