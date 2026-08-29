# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Clasp 3.0.1 supports LLVM 15-20 and 22. LLVM 21 is skipped for an API
# break. llvm-r2 drops slots older than 17.
LLVM_COMPAT=( {17..20} 22 )
CHECKREQS_MEMORY="8G"
CHECKREQS_DISK_BUILD="8G"

inherit check-reqs edo flag-o-matic llvm-r2 multiprocessing ninja-utils toolchain-funcs

DESCRIPTION="Common Lisp implementation that interoperates with C++ via LLVM"
HOMEPAGE="https://github.com/clasp-developers/clasp"
SRC_URI="https://github.com/clasp-developers/clasp/releases/download/${PV}/clasp-${PV}.tar.gz"
S="${WORKDIR}/clasp-${PV}"

LICENSE="LGPL-2+ Sleepycat MIT public-domain"
SLOT="0"
KEYWORDS="~amd64"
RESTRICT="strip"

# Arch AUR clasp-cl 3.0.1-2: koga --skip-sync --reproducible-build with
# bin/share/lib/dylib paths, ninja install, !strip. SBCL is the host Lisp.
# LLVM/clang/lld stay slotted; koga is pointed at the matching llvm-config.
RDEPEND="
	dev-libs/boost:=
	dev-libs/expat
	dev-libs/gmp:=[cxx]
	dev-libs/libbsd
	dev-libs/libedit
	dev-libs/libffi:=
	>=dev-libs/libfmt-7.1.0:=
	sys-libs/ncurses:=
	virtual/libelf
	virtual/zlib:=
	$(llvm_gen_dep '
		llvm-core/clang:${LLVM_SLOT}=
		llvm-core/lld:${LLVM_SLOT}=
		llvm-core/llvm:${LLVM_SLOT}=
	')
"
DEPEND="${RDEPEND}"
BDEPEND="
	app-alternatives/ninja
	dev-lisp/sbcl
	virtual/pkgconfig
"

DOCS=( CONTRIBUTING.md README.md RELEASE_NOTES.md SECURITY.md )

pkg_setup() {
	check-reqs_pkg_setup
	llvm-r2_pkg_setup
}

src_configure() {
	strip-unsupported-flags
	filter-ldflags -s

	# koga writes DESTDIR into the ninja files; they do not honor DESTDIR
	# at install time. --package-path only affects the install rules.
	local llvm_bin
	llvm_bin="$(get_llvm_prefix -b)/bin"

	local mykoga=(
		--skip-sync
		--reproducible-build
		--jobs="$(makeopts_jobs)"
		--package-path="${ED}"
		--bin-path="${EPREFIX}/usr/bin/"
		--share-path="${EPREFIX}/usr/share/clasp/"
		--lib-path="${EPREFIX}/usr/$(get_libdir)/clasp/"
		--dylib-path="${EPREFIX}/usr/$(get_libdir)/"
		--pkgconfig-path="${EPREFIX}/usr/$(get_libdir)/pkgconfig/"
		--llvm-config="${llvm_bin}/llvm-config"
		--cc="${llvm_bin}/clang"
		--cxx="${llvm_bin}/clang++"
		--ld=lld
		--pkg-config="$(tc-getPKG_CONFIG)"
		--ldflags="${LDFLAGS}"
	)

	# SBCL writes caches under HOME.
	export HOME="${T}"
	export CLASP_BUILD_JOBS="$(makeopts_jobs)"

	edo ./koga "${mykoga[@]}"
}

src_compile() {
	export HOME="${T}"
	export CLASP_BUILD_JOBS="$(makeopts_jobs)"
	edob eninja -C build
}

src_test() {
	export HOME="${T}"
	edo ./build/boehmprecise/clasp --norc --disable-debugger --non-interactive \
		--eval '(ext:quit (if (eql (* 6 7) 42) 0 1))'
}

src_install() {
	export HOME="${T}"
	eninja -C build install
	einstalldocs
	[[ -d licenses ]] && dodoc -r licenses
	[[ -f docs/clasp.1 ]] && doman docs/clasp.1
}
