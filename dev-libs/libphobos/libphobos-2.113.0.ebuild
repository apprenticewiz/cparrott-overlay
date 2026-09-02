# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit flag-o-matic multiprocessing toolchain-funcs

# Arch extra/dmd ships dmd 2.113.0 with phobos tag v2.113.0.
PHOBOS_PV="2.113.0"

DESCRIPTION="The Phobos standard library and Druntime for the D language"
HOMEPAGE="https://dlang.org/"
SRC_URI="
	https://github.com/dlang/phobos/archive/refs/tags/v${PHOBOS_PV}.tar.gz
		-> phobos-${PHOBOS_PV}.tar.gz
	https://github.com/dlang/dmd/archive/refs/tags/v${PV}.tar.gz
		-> dmd-${PV}.tar.gz
"
S="${WORKDIR}/phobos-${PHOBOS_PV}"

LICENSE="Boost-1.0"
SLOT="0/113"
KEYWORDS="~amd64"

# libphobos must not BDEPEND on dmd: dmd DEPEND on this package, and a
# || (bootstrap dmd) still looks like a cycle to Portage.
BDEPEND=">=dev-lang/dmd-bootstrap-2.112.1"
RDEPEND="net-misc/curl"

src_prepare() {
	default

	# Keep VERSION from the tag, not a -dirty git describe.
	sed -i 's/\.git/.nope/' "${WORKDIR}/dmd-${PV}/compiler/src/build.d" || die
}

src_compile() {
	filter-lto

	local dmd_src="${WORKDIR}/dmd-${PV}"
	local host_dmd stage1

	# The host compiler only has to build the dmd sources. It cannot build
	# this release's runtime: Druntime 2.113 uses __traits(needsDestruction),
	# which 2.112 does not implement.
	if [[ -x ${BROOT}/usr/lib/dmd-bootstrap/bin/dmd ]]; then
		host_dmd="${BROOT}/usr/lib/dmd-bootstrap/bin/dmd"
	elif has_version -b ">=dev-lang/dmd-${PV}" && [[ -x ${BROOT}/usr/bin/dmd ]]; then
		host_dmd="${BROOT}/usr/bin/dmd"
	else
		die "Need >=dev-lang/dmd-bootstrap-2.112.1"
	fi

	# So build a stage1 compiler from the bundled dmd source and compile the
	# runtime with that. Arch gets this for free by building the compiler and
	# libphobos in one PKGBUILD; the split here has to redo the compiler.
	pushd "${dmd_src}" >/dev/null || die
	mkdir -p generated || die
	"${host_dmd}" -ofgenerated/build -g compiler/src/build.d -release -O || die
	generated/build \
		BUILD=release \
		HOST_DMD="${host_dmd}" \
		CXX="$(tc-getCXX)" \
		ENABLE_RELEASE=1 \
		SYSCONFDIR="${EPREFIX}/etc" \
		-j"$(makeopts_jobs)" \
		dmd || die
	popd >/dev/null || die

	stage1=$(find "${dmd_src}/generated/linux/release" -name dmd -type f -print -quit)
	[[ -n ${stage1} ]] || die "stage1 dmd not built"

	# Arch: make -f posix.mak in druntime then phobos. These makefiles pass
	# -conf=, so no dmd.conf is read and a half-installed libphobos in ROOT
	# is ignored.
	emake -C "${dmd_src}/druntime" \
		DMD="${stage1}" \
		CC="$(tc-getCC)" \
		BUILD=release \
		ENABLE_RELEASE=1 \
		PIC=1 \
		OS=linux

	emake \
		DMD="${stage1}" \
		DMD_DIR="${dmd_src}" \
		CC="$(tc-getCC)" \
		BUILD=release \
		ENABLE_RELEASE=1 \
		PIC=1 \
		OS=linux
}

src_install() {
	local dmd_src="${WORKDIR}/dmd-${PV}"
	local dest="${ED}/usr/$(get_libdir)"
	local f

	mkdir -p "${dest}" || die
	# Arch package_libphobos: cp -P generated *.a / *.so* (skip *.so.a).
	while IFS= read -r -d '' f; do
		case ${f} in
			*.so.a) continue ;;
		esac
		cp -P "${f}" "${dest}/" || die
	done < <(find \
		"${dmd_src}/generated/linux/release" \
		"${S}/generated/linux/release" \
		\( -name '*.a' -o -name '*.so*' \) ! -name '*.o' -print0)

	chmod 0644 "${dest}"/*.a || die
	if [[ -n $(echo "${dest}"/*.so*) && ${dest}/*.so* != "${dest}/*.so*" ]]; then
		chmod 0755 "${dest}"/*.so* || die
	fi

	insinto /usr/include/dlang/dmd
	doins "${S}"/*.d
	doins -r "${S}"/etc "${S}"/std
	doins -r "${dmd_src}"/druntime/import/*

	dodoc LICENSE_1_0.txt
	newdoc "${dmd_src}/LICENSE.txt" LICENSE-druntime.txt
}
