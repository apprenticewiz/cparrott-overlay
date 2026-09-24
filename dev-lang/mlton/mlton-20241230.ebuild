# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit check-reqs flag-o-matic toolchain-funcs

DESCRIPTION="Standard ML optimizing compiler and libraries"
HOMEPAGE="http://mlton.org https://github.com/MLton/mlton"
BASE_URI="https://github.com/MLton/mlton/releases/download/on-${PV}-release"
BIN_AMD64="${P}-1.amd64-linux.ubuntu-24.04_glibc2.39"
BIN_ARM64="${P}-1.arm64-linux.ubuntu-24.04-arm_glibc2.39"
# The upstream binary is always fetched: it is either installed as-is
# (USE=binary) or used as the bootstrap compiler for the source build.
SRC_URI="
	!binary? ( ${BASE_URI}/${P}.src.tgz )
	amd64? ( ${BASE_URI}/${BIN_AMD64}.tgz )
	arm64? ( ${BASE_URI}/${BIN_ARM64}.tgz )
"
S="${WORKDIR}"

LICENSE="HPND MIT"
SLOT="0/${PV}"
KEYWORDS="~amd64 ~arm64"
IUSE="binary"

DEPEND="dev-libs/gmp:="
RDEPEND="${DEPEND}"

QA_PREBUILT="usr/bin/* usr/lib*/mlton/*"

mlton_bindir() {
	use amd64 && echo "${WORKDIR}/${BIN_AMD64}"
	use arm64 && echo "${WORKDIR}/${BIN_ARM64}"
}

mlton_srcdir() {
	if use binary; then
		mlton_bindir
	else
		echo "${WORKDIR}/${P}"
	fi
}

mlton_check_reqs() {
	use binary && return
	# Self-compiling the compiler is a single whole-program build.
	CHECKREQS_MEMORY="4G" check-reqs_"${EBUILD_PHASE_FUNC}"
}

pkg_pretend() {
	mlton_check_reqs
}

pkg_setup() {
	mlton_check_reqs
}

src_configure() {
	# bug 863266
	filter-lto
}

src_compile() {
	local args=(
		CC="$(tc-getCC)"
		WITH_GMP_INC_DIR="${ESYSROOT}/usr/include"
		WITH_GMP_LIB_DIR="${ESYSROOT}/usr/$(get_libdir)"
	)

	cd "$(mlton_srcdir)" || die

	if use binary; then
		# Re-detect the local compiler's PIE/PIC default and GMP location.
		emake "${args[@]}" update
		return
	fi

	# mllex/mlyacc for the first round come from the bootstrap binary.
	local -x PATH="$(mlton_bindir)/bin:${PATH}"
	emake -j1 "${args[@]}" \
		AR="$(tc-getAR)" \
		RANLIB="$(tc-getRANLIB)" \
		CFLAGS="${CFLAGS}" \
		LDFLAGS="${LDFLAGS}" \
		OLD_MLTON_DIR="$(mlton_bindir)/bin" \
		all
}

src_install() {
	local args=(
		PREFIX="${EPREFIX}/usr"
		libdir="${EPREFIX}/usr/$(get_libdir)"
		docdir="${EPREFIX}/usr/share/doc/${PF}"
		DESTDIR="${D}"
	)

	cd "$(mlton_srcdir)" || die

	if use binary; then
		emake "${args[@]}" install
	else
		emake "${args[@]}" GZIP_MAN=false install-no-strip install-docs
	fi

	# The -dbg runtime variants back 'mlton -debug true'.
	dostrip -x "/usr/$(get_libdir)/mlton/targets"
	# The guide ships archived attachments.
	docompress -x "/usr/share/doc/${PF}/guide"
}
