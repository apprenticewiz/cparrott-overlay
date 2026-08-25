# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Chapel 2.9 supports LLVM 14–22; llvm-r2's oldest slot is 17.
LLVM_COMPAT=( {17..22} )
PYTHON_COMPAT=( python3_{11..15} )

inherit check-reqs flag-o-matic llvm-r2 python-single-r1 toolchain-funcs

DESCRIPTION="Programming language designed for productive parallel computing at scale"
HOMEPAGE="https://chapel-lang.org/"
SRC_URI="https://github.com/chapel-lang/chapel/releases/download/${PV}/${P}.tar.gz"

LICENSE="Apache-2.0 BSD MIT"
SLOT="0"
KEYWORDS="~amd64"
IUSE="test"
REQUIRED_USE="${PYTHON_REQUIRED_USE}"
RESTRICT="!test? ( test )"

# Chapel's default build also compiles bundled qthreads, re2, utf8-decoder,
# and whereami. LLVM/GMP/hwloc/jemalloc/libunwind come from the system.
RDEPEND="
	${PYTHON_DEPS}
	app-shells/bash
	dev-lang/perl
	dev-libs/gmp:=
	dev-libs/jemalloc:=
	sys-apps/hwloc:=
	sys-libs/libunwind:=
	sys-libs/ncurses:=
	$(llvm_gen_dep '
		llvm-core/clang:${LLVM_SLOT}=
		llvm-core/llvm:${LLVM_SLOT}=
	')
"
DEPEND="${RDEPEND}"
BDEPEND="
	>=dev-build/cmake-3.20
	sys-devel/m4
	virtual/pkgconfig
"

# System LLVM needs about 2G; bundled LLVM would need 4G.
CHECKREQS_MEMORY="2G"

pkg_pretend() {
	check-reqs_pkg_pretend
}

pkg_setup() {
	check-reqs_pkg_setup
	llvm-r2_pkg_setup
	python-single-r1_pkg_setup
}

chapel_env() {
	# Matches the AUR PKGBUILD's ./configure --prefix=/usr plus Homebrew's
	# system-library chplconfig. Host jemalloc is bundled-only on Linux, so
	# the compiler itself uses libc malloc.
	export CHPL_LLVM=system
	export CHPL_LLVM_CONFIG="$(get_llvm_prefix)/bin/llvm-config"
	export CHPL_LLVM_SUPPORT=system
	export CHPL_GMP=system
	export CHPL_HWLOC=system
	export CHPL_UNWIND=system
	export CHPL_RE2=bundled
	export CHPL_TARGET_MEM=jemalloc
	export CHPL_TARGET_JEMALLOC=system
	export CHPL_HOST_MEM=cstdlib
	export CHPL_HOST_JEMALLOC=none
	export CHPL_HOST_CC="$(tc-getCC)"
	export CHPL_HOST_CXX="$(tc-getCXX)"
	export CHPL_MAKE=make
	export CHPL_CMAKE_USE_CC_CXX=1
	export CHPL_CMAKE_PYTHON="${EPYTHON}"
}

src_prepare() {
	default
	python_fix_shebang -f util
}

src_configure() {
	# AUR options=('!lto')
	filter-lto
	chapel_env
	# configure writes chplconfig and requires CHPL_HOME to be unset or PWD.
	unset CHPL_HOME
	# Do not use econf: only --prefix and --chpl-home are accepted.
	./configure --prefix="${EPREFIX}/usr" || die
}

src_compile() {
	chapel_env
	export CHPL_HOME="${S}"
	# Top-level Makefile is .NOTPARALLEL; recursive makes still honor MAKEOPTS.
	emake
}

src_test() {
	chapel_env
	export CHPL_HOME="${S}"
	emake check
}

src_install() {
	chapel_env
	export CHPL_HOME="${S}"
	emake DESTDIR="${D}" install
}
