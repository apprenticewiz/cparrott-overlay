# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

BV="${PV}-1"
BV_AMD64="${BV}-linux-x86_64"
BV_ARM64="${BV}-linux-aarch64"
BV_LOONG="${BV}-linux-loongarch64"
# Branch extra-arches-${PV} of apprenticewiz/crystal: upstream ${PV} plus
# the loongarch64-linux-gnu target.
CRYSTAL_COMMIT="cb37aeb446a81d76274bc18cc0b5e4bcc932c091"

LLVM_COMPAT=( {20..22} )

inherit llvm-r2 multiprocessing shell-completion toolchain-funcs

DESCRIPTION="The Crystal Programming Language"
HOMEPAGE="https://crystal-lang.org/
	https://github.com/crystal-lang/crystal/"

SRC_URI="
	https://github.com/apprenticewiz/${PN}/archive/${CRYSTAL_COMMIT}.tar.gz
		-> ${P}-${CRYSTAL_COMMIT:0:9}.gh.tar.gz
	amd64? (
		https://github.com/crystal-lang/${PN}/releases/download/${BV/-*}/${PN}-${BV_AMD64}.tar.gz
	)
	arm64? (
		https://github.com/crystal-lang/${PN}/releases/download/${BV/-*}/${PN}-${BV_ARM64}.tar.gz
	)
	loong? (
		https://github.com/apprenticewiz/cparrott-overlay/releases/download/${PN}-${BV}-loongarch64/${PN}-${BV_LOONG}.tar.gz
	)
"
S="${WORKDIR}/${PN}-${CRYSTAL_COMMIT}"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="amd64 ~arm64 ~loong"
IUSE="doc debug llvm-libunwind"
RESTRICT="test"  # Upstream test suite not reliable.

DEPEND="
	dev-libs/boehm-gc:=[threads]
	dev-libs/gmp:=
	dev-libs/libatomic_ops:=
	dev-libs/libevent:=
	dev-libs/libffi:=
	dev-libs/libpcre2:=[unicode]
	dev-libs/libxml2:=
	dev-libs/libyaml
	dev-libs/pcl:=
	$(llvm_gen_dep '
		llvm-core/llvm:${LLVM_SLOT}=
	')
	llvm-libunwind? (
		llvm-runtimes/libunwind:=
	)
	!llvm-libunwind? (
		sys-libs/libunwind:=
	)
"
RDEPEND="
	${DEPEND}
"

PATCHES=(
	"${FILESDIR}/${PN}-0.27.0-gentoo-tests-long-unix.patch"
	"${FILESDIR}/${PN}-0.27.0-gentoo-tests-long-unix-2.patch"
	"${FILESDIR}/${PN}-1.15.0-remove-enviroment-clearing-tests.patch"
)

# Do not complain about CFLAGS etc. Crystal rebuilds itself.
QA_FLAGS_IGNORED='.*'

src_prepare() {
	default

	# Link against system boehm-gc instead of upstream prebuilt static library
	# bug #929123, #929989 and #931100
	# https://github.com/crystal-lang/crystal/issues/12035#issuecomment-2522606612
	rm "${WORKDIR}/crystal-${BV}"/lib/crystal/libgc.a || die
}

src_configure() {
	local bootstrap_path="${WORKDIR}/${PN}-${BV}/bin"

	if [[ ! -d "${bootstrap_path}" ]] ; then
		eerror "Binary tarball does not contain expected directory:"
		die "'${bootstrap_path}' path does not exist."
	fi

	# crystal uses 'LLVM_TARGETS' to override default list of targets
	unset LLVM_TARGETS

	MY_EMAKE_COMMON_ARGS=(
		PATH="${bootstrap_path}:${PATH}"

		CRYSTAL_CONFIG_VERSION="${PV}"
		CRYSTAL_CONFIG_PATH="lib:${EPREFIX}/usr/$(get_libdir)/crystal"

		$(usex debug "" release=1)
		interpreter="true"

		threads="$(makeopts_jobs)"
		check_lld="" # disable opportunistic lld
		progress="true"
		stats="true"
		verbose="true"

		AR="$(tc-getAR)"
		CC="$(tc-getCC)"
		CXX="$(tc-getCXX)"
		LLVM_CONFIG="$(get_llvm_prefix -d)/bin/llvm-config"
	)
}

src_compile() {
	emake "${MY_EMAKE_COMMON_ARGS[@]}"

	if use doc ; then
		emake docs "${MY_EMAKE_COMMON_ARGS[@]}"
	fi
}

src_test() {
	nonfatal emake std_spec "${MY_EMAKE_COMMON_ARGS[@]}"
}

src_install() {
	insinto "/usr/$(get_libdir)/crystal"
	doins -r src/.

	exeinto /usr/bin
	doexe .build/crystal

	newbashcomp etc/completion.bash "${PN}"
	newfishcomp etc/completion.fish crystal.fish
	newzshcomp etc/completion.zsh _crystal

	dodoc -r samples

	if use doc ; then
		docinto api
		dodoc -r docs/.
	fi
}
