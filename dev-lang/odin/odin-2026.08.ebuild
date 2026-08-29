# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# build_odin.sh accepts LLVM 17-22. Arch extra/odin pins llvm21.
LLVM_COMPAT=( {17..22} )

inherit flag-o-matic llvm-r2 toolchain-funcs

MY_PV="dev-${PV//./-}"

DESCRIPTION="Data-oriented programming language"
HOMEPAGE="https://odin-lang.org/ https://github.com/odin-lang/Odin"
SRC_URI="https://github.com/odin-lang/Odin/archive/refs/tags/${MY_PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/Odin-${MY_PV}"

LICENSE="ZLIB"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="test"
RESTRICT="!test? ( test )"

# Vendored raylib (and similar) Linux binaries come from Git LFS in the tag.
QA_PREBUILT="usr/lib/odin/vendor/*"

# Arch extra/odin  dev_2026_08-1: clang + llvm21-libs at runtime, llvm21
# to build, python/miniaudio/stb listed but unused by the PKGBUILD (python
# is only tests/core/download_assets.py; stb/miniaudio stay vendored).
RDEPEND="
	$(llvm_gen_dep '
		llvm-core/clang:${LLVM_SLOT}=
		llvm-core/llvm:${LLVM_SLOT}=
	')
"
DEPEND="${RDEPEND}"
BDEPEND="
	$(llvm_gen_dep '
		llvm-core/clang:${LLVM_SLOT}=
		llvm-core/llvm:${LLVM_SLOT}=
	')
"

pkg_setup() {
	llvm-r2_pkg_setup
}

src_prepare() {
	default

	# Tarball has no git metadata; otherwise ODIN_VERSION_RAW becomes
	# whatever month the package is built in.
	sed -i -e "s/GIT_DATE=\$(date +\"%Y-%m\")/GIT_DATE=${PV//./-}/" \
		build_odin.sh || die
}

src_compile() {
	filter-lto

	local llvm_bindir
	llvm_bindir="$(get_llvm_prefix -b)/bin"

	tc-export CC AR
	export CXX="${llvm_bindir}/clang++"
	export LLVM_CONFIG="${llvm_bindir}/llvm-config"

	emake release

	# Arch only builds cgltf. Also produce the other Unix static vendor
	# libs so vendor:stb and vendor:miniaudio work from the source tree
	# (GitHub archives do not ship those .a files).
	sh vendor/cgltf/src/build_cgltf.sh unix || die
	sh vendor/stb/src/build_stb.sh unix || die
	sh vendor/miniaudio/src/build_miniaudio.sh || die
}

src_test() {
	./odin version || die
	./odin build examples/demo -out:"${T}/odin-demo" || die
}

src_install() {
	local libdir="/usr/lib/odin"

	exeinto "${libdir}"
	doexe odin

	# Preserve vendor prebuilt library modes (Arch: cp -r).
	insinto "${libdir}"
	doins -r base core shared
	cp -a vendor "${ED}${libdir}/" || die

	dosym -r "${libdir}/odin" /usr/bin/odin

	dodoc README.md PROPOSAL-PROCESS.md
	dodoc LICENSE
}
