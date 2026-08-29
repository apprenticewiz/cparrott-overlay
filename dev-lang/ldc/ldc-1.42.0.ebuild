# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# LDC 1.42 supports LLVM 15–21. llvm-r2 defaults to the newest slot in
# this range (21); llvm_slot_15 through llvm_slot_20 remain available.
LLVM_COMPAT=( {15..21} )

inherit cmake flag-o-matic llvm-r2

DESCRIPTION="LLVM-based D compiler (LDC) with Druntime and Phobos"
HOMEPAGE="https://github.com/ldc-developers/ldc"
SRC_URI="https://github.com/ldc-developers/ldc/releases/download/v${PV}/ldc-${PV}-src.tar.gz"
S="${WORKDIR}/ldc-${PV}-src"

LICENSE="BSD Boost-1.0 Apache-2.0-with-LLVM-exceptions"
SLOT="0"
KEYWORDS="~amd64"
RESTRICT="test"

# dmd-bootstrap is listed before dmd so a first install does not pull
# the full compiler. An installed dmd or ldc still satisfies the ||.
#
# Compiler and liblphobos stay in one package because cmake produces both
# in a single build (the runtime is compiled by that new ldc2). Splitting
# like Arch would either rebuild the tree or recreate the dmd/libphobos
# cycle.
RDEPEND="
	net-misc/curl
	sys-devel/gcc
	$(llvm_gen_dep '
		llvm-core/llvm:${LLVM_SLOT}=
		llvm-runtimes/compiler-rt:${LLVM_SLOT}=
	')
"
DEPEND="${RDEPEND}"
BDEPEND="
	>=dev-build/cmake-3.16
	|| (
		>=dev-lang/ldc-1.40
		>=dev-lang/dmd-bootstrap-2.112.1
		>=dev-lang/dmd-2.111
	)
	$(llvm_gen_dep '
		llvm-core/llvm:${LLVM_SLOT}=
		llvm-core/lld:${LLVM_SLOT}=
	')
"

pkg_setup() {
	llvm-r2_pkg_setup
}

host_d() {
	if has_version -b ">=dev-lang/ldc-1.40" && [[ -x ${BROOT}/usr/bin/ldmd2 ]]; then
		echo "${BROOT}/usr/bin/ldmd2"
	elif has_version -b ">=dev-lang/dmd-2.111" && [[ -x ${BROOT}/usr/bin/dmd ]]; then
		echo "${BROOT}/usr/bin/dmd"
	elif [[ -x ${BROOT}/usr/lib/dmd-bootstrap/bin/dmd ]]; then
		echo "${BROOT}/usr/lib/dmd-bootstrap/bin/dmd"
	else
		die "Need ldc, dmd, or dmd-bootstrap as the host D compiler"
	fi
}

src_prepare() {
	# Arch PKGBUILD: LLVMDebuginfod required curl
	sed -i 's/-lLLVMDebuginfod/-lLLVMDebuginfod -lcurl/' tools/CMakeLists.txt || die
	cmake_src_prepare
}

src_configure() {
	# Arch options=(!lto): linking ldc2 fails with LTO.
	filter-lto

	local host
	host="$(host_d)"

	local mycmakeargs=(
		-DCMAKE_SKIP_RPATH=ON
		-DINCLUDE_INSTALL_DIR="${EPREFIX}/usr/include/dlang/ldc"
		-DBUILD_SHARED_LIBS=BOTH
		-DBUILD_LTO_LIBS=ON
		-DLDC_WITH_LLD=OFF
		-DD_COMPILER="${host}"
		-DLLVM_ROOT_DIR="$(get_llvm_prefix)"
		-DSYSCONF_INSTALL_DIR="${EPREFIX}/etc"
		-DBASH_COMPLETION_COMPLETIONSDIR="${EPREFIX}/usr/share/bash-completion/completions"
	)

	# Arch D_COMPILER_FLAGS are ldc-only (-link-defaultlib-shared, --flto).
	# dmd rejects those, so only pass them when self-hosting with ldmd2.
	if [[ ${host} == *ldmd2 ]]; then
		mycmakeargs+=(
			-DD_COMPILER_FLAGS="-link-defaultlib-shared=false -linker=lld"
		)
	fi

	cmake_src_configure
}

src_install() {
	cmake_src_install

	dosym ldc2 /usr/bin/ldc
	dosym ldmd2 /usr/bin/ldmd
	if [[ -e ${ED}/usr/share/bash-completion/completions/ldc2 ]]; then
		dosym ldc2 /usr/share/bash-completion/completions/ldc
	fi
}
