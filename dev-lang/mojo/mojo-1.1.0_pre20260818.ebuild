# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit check-reqs multiprocessing

COMMIT="e41ef364252c5325e2473300f657ba40bb1187e7"
BAZEL_COMMIT="46c5e789f84c7bf4ba1edb105eefa7bc4ebc841b"

DESCRIPTION="Systems programming language for heterogeneous computing"
HOMEPAGE="https://www.modular.com/mojo https://github.com/modular/modular"
SRC_URI="
	fetch+https://github.com/modular/modular/archive/${COMMIT}.tar.gz
		-> ${P}.tar.gz
	amd64? (
		fetch+https://storage.googleapis.com/bazel-builds/artifacts/linux/${BAZEL_COMMIT}/bazel
			-> ${P}-bazel-amd64
		${P}-bazel-vendor-amd64.tar.zst
	)
"
S="${WORKDIR}/modular-${COMMIT}"

LICENSE="Apache-2.0-with-LLVM-exceptions"
SLOT="0"
KEYWORDS="~amd64"

# Upstream has no release containing the newly opened compiler source yet.
# The Bazel graph also has no lockfile and downloads several gigabytes of
# patched toolchains and generated repositories.  Require the reproducible
# target-specific bundle made by scripts/mojo-bazel-vendor.sh.
RESTRICT="fetch test"

RDEPEND="
	app-arch/zstd:=
	dev-libs/libxml2-compat:2/2
	dev-libs/libbsd:=
	sys-libs/ncurses:=
	virtual/zlib:=
"
DEPEND="${RDEPEND}"
BDEPEND="
	app-arch/zstd
	dev-libs/libxml2-compat:2/2
"

CHECKREQS_DISK_BUILD="32G"
CHECKREQS_MEMORY="12G"

pkg_nofetch() {
	einfo "Mojo needs a target-specific offline Bazel dependency bundle."
	einfo "Generate it with the overlay helper and place it in DISTDIR:"
	einfo
	einfo "  scripts/mojo-bazel-vendor.sh /var/cache/distfiles"
	einfo
	einfo "The public source archive and pinned Bazel binary are fetched"
	einfo "normally; only ${P}-bazel-vendor-${ARCH}.tar.zst is manual."
}

src_unpack() {
	unpack "${P}.tar.gz"

	# Portage's unpack has no zstd support, so extract the bundle directly.
	tar --zstd -xf "${DISTDIR}/${P}-bazel-vendor-${ARCH}.tar.zst" \
		-C "${WORKDIR}" || die
}

src_prepare() {
	default

	# .bazelrc imports this file after the upstream bazelw wrapper generates it.
	# We invoke the pinned Bazel binary directly to avoid another download.
	mkdir -p build || die
	: > build/wrapper.bazelrc || die

	# Bzlmod only resolves modules from the vendored registry when the lockfile
	# pins them; without it Bazel contacts the Bazel Central Registry.  Upstream
	# does not commit a lockfile, so use the one recorded while vendoring.
	cp "${WORKDIR}/MODULE.bazel.lock" MODULE.bazel.lock || die
}

src_compile() {
	local bazel="${T}/bazel"
	cp "${DISTDIR}/${P}-bazel-${ARCH}" "${bazel}" || die
	chmod +x "${bazel}" || die

	local -a bazel_args=(
		--output_user_root="${T}/bazel-root"
		build
		--vendor_dir="${WORKDIR}/mojo-vendor"
		--repository_cache="${WORKDIR}/mojo-cache"
		--repository_disable_download
		--config=build-mojo
		--config=disable-lint
		--compilation_mode=opt
		--//:modular_config=release
		--build_runfile_links=true
		--jobs="$(makeopts_jobs)"
		//KGEN:mojo
	)

	HOME="${T}/home" "${bazel}" "${bazel_args[@]}" || die
}

src_install() {
	local output="bazel-bin/KGEN/tools/mojo/mojo-full"
	local libexec="/usr/libexec/mojo"
	local toolchain_arch

	case ${ARCH} in
		amd64) toolchain_arch=x86_64 ;;
		*) die "unsupported architecture ${ARCH}" ;;
	esac

	[[ -x ${output} ]] || die "Mojo compiler output not found"
	[[ -d ${output}.runfiles ]] || die "Mojo runfiles tree not found"

	dodir "${libexec}"
	cp -aL "${output}" "${ED}${libexec}/mojo-full" || die
	cp -aL "${output}.runfiles" \
		"${ED}${libexec}/mojo-full.runfiles" || die

	# The target advertises all three upstream build hosts as runfiles.
	# Install only this package's Linux toolchain, and remove a redundant copy
	# of the top-level compiler. The runtime resolves the remaining files from
	# the directory tree, so the build-directory MANIFEST must not be kept.
	rm -rf \
		"${ED}${libexec}/mojo-full.runfiles/+http_archive+clang-linux-"* \
		"${ED}${libexec}/mojo-full.runfiles/+http_archive+clang-macos" \
		"${ED}${libexec}/mojo-full.runfiles/+http_archive+llvm-ifs" \
		"${ED}${libexec}/mojo-full.runfiles/_main/KGEN/tools/mojo/mojo-full" \
		"${ED}${libexec}/mojo-full.runfiles/MANIFEST" \
		|| die
	cp -aL \
		"${output}.runfiles/+http_archive+clang-linux-${toolchain_arch}" \
		"${ED}${libexec}/mojo-full.runfiles/" \
		|| die

	cat > "${T}/mojo" <<-EOF || die
		#!/bin/sh
		export MODULAR_CRASH_REPORTING_ENABLED=0
		export MODULAR_MOJO_MAX_IMPORT_PATH="${EPREFIX}${libexec}/mojo-full.runfiles/_main/mojo/stdlib/std"
		exec "${EPREFIX}${libexec}/mojo-full" "\$@"
	EOF
	dobin "${T}/mojo"

	dodoc README.md
}
