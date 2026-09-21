# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# This LDC release supports LLVM 15–21. llvm-r2 defaults to the newest
# slot in this range; llvm_slot_15 through llvm_slot_20 remain available.
LLVM_COMPAT=( {15..21} )

inherit cmake flag-o-matic llvm-r2

DESCRIPTION="LLVM-based D compiler (LDC) with Druntime and Phobos"
HOMEPAGE="https://github.com/ldc-developers/ldc"
SRC_URI="
	https://github.com/ldc-developers/ldc/releases/download/v${PV}/ldc-${PV}-src.tar.gz
	amd64? (
		https://github.com/ldc-developers/ldc/releases/download/v${PV}/ldc2-${PV}-linux-x86_64.tar.xz
	)
	arm64? (
		https://github.com/ldc-developers/ldc/releases/download/v${PV}/ldc2-${PV}-linux-aarch64.tar.xz
	)
"
S="${WORKDIR}/ldc-${PV}-src"

LICENSE="BSD Boost-1.0 Apache-2.0-with-LLVM-exceptions"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
RESTRICT="test"

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
	$(llvm_gen_dep '
		llvm-core/llvm:${LLVM_SLOT}=
		llvm-core/lld:${LLVM_SLOT}=
	')
"

pkg_setup() {
	llvm-r2_pkg_setup

	# The upstream prebuilt ldc2/ldmd2 link mimalloc. Its first allocation
	# runs mi_process_init(), which calls open()/access() while libsandbox is
	# still inside the dlopen() of its own open() wrapper. That wrapper's
	# mutex is not recursive, so the bootstrap compiler deadlocks on startup
	# and never prints anything. Handing mimalloc the NUMA node count skips
	# the /sys probe that trips this.
	export MIMALLOC_USE_NUMA_NODES=1
}

host_d() {
	local bootstrap_arch

	case ${ARCH} in
		amd64) bootstrap_arch=x86_64 ;;
		arm64) bootstrap_arch=aarch64 ;;
		*) die "unsupported architecture ${ARCH}" ;;
	esac

	local compiler="${WORKDIR}/ldc2-${PV}-linux-${bootstrap_arch}/bin/ldmd2"
	[[ -x ${compiler} ]] || die "bootstrap compiler not found: ${compiler}"
	echo "${compiler}"
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

	mycmakeargs+=(
		-DD_COMPILER_FLAGS="-link-defaultlib-shared=false -linker=lld"
	)

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
