# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Upstream: "any recent LLVM; tested with 22.x". C++23 needs GCC 14 / Clang 18.
LLVM_COMPAT=( {18..23} )

inherit cmake flag-o-matic llvm-r2

DESCRIPTION="LLVM-based Pascal compiler (ISO 7185, ISO 10206, Turbo)"
HOMEPAGE="https://github.com/apprenticewiz/plang"
SRC_URI="https://github.com/apprenticewiz/plang/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="Apache-2.0-with-LLVM-exceptions"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="test"
RESTRICT="!test? ( test )"

RDEPEND="
	sys-devel/gcc
	$(llvm_gen_dep '
		llvm-core/llvm:${LLVM_SLOT}=
		llvm-core/lld:${LLVM_SLOT}=
	')
"
DEPEND="${RDEPEND}"
BDEPEND="
	>=sys-devel/gcc-14
	$(llvm_gen_dep '
		llvm-core/llvm:${LLVM_SLOT}=
		llvm-core/lld:${LLVM_SLOT}=
	')
"

pkg_setup() {
	llvm-r2_pkg_setup
}

src_configure() {
	# LTO across plang and LLVM is not something upstream tests.
	filter-lto

	local mycmakeargs=(
		-DPLANG_ENABLE_TESTS=OFF
		-DPLANG_ENABLE_FUZZERS=OFF
		-DPLANG_ENABLE_RUNTIME_SANITIZER_TESTS=OFF
		-DLLVM_DIR="$(get_llvm_prefix -d)/$(get_libdir)/cmake/llvm"
	)
	cmake_src_configure
}

src_test() {
	# Full suite needs GoogleTest plus lit/FileCheck. Smoke-test the driver
	# instead: compile and run a one-liner the way a user would.
	local hello="${T}/hello.pas"
	printf '%s\n' "program hello; begin writeln('ok') end." > "${hello}" || die
	"${BUILD_DIR}/bin/plang" "${hello}" -o "${T}/hello" || die
	[[ $( "${T}/hello" ) == ok ]] || die "compiled program produced unexpected output"
}

src_install() {
	cmake_src_install
	dodoc README.md CHANGELOG.md
}
