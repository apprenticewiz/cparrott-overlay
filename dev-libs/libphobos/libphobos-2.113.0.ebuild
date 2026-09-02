# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit flag-o-matic toolchain-funcs

# Arch extra/dmd ships dmd 2.112.1 with phobos tag v2.112.0.
PHOBOS_PV="2.112.0"

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
SLOT="0/112"
KEYWORDS="~amd64"

# dmd-bootstrap is listed first so a first install does not pull dev-lang/dmd,
# which depends on this package. Rebuilds use an installed dmd of the same
# version, so dmd-bootstrap can be depcleaned afterwards.
BDEPEND="
	|| (
		~dev-lang/dmd-bootstrap-${PV}
		~dev-lang/dmd-${PV}
	)
"
RDEPEND="net-misc/curl"

src_compile() {
	filter-lto

	local dmd_src="${WORKDIR}/dmd-${PV}"
	local dmd

	# Prefer an installed dmd of the same version; fall back to the bootstrap.
	# Both are invoked with -conf= by these makefiles, so neither reads a
	# dmd.conf and the half-installed libphobos in ROOT is never picked up.
	if has_version -b "~dev-lang/dmd-${PV}"; then
		dmd="${BROOT}/usr/bin/dmd"
	elif [[ -x ${BROOT}/usr/lib/dmd-bootstrap/bin/dmd ]]; then
		dmd="${BROOT}/usr/lib/dmd-bootstrap/bin/dmd"
	else
		die "Need ~dev-lang/dmd-${PV} or ~dev-lang/dmd-bootstrap-${PV}"
	fi

	# Arch: make -f posix.mak in druntime then phobos.
	emake -C "${dmd_src}/druntime" \
		DMD="${dmd}" \
		CC="$(tc-getCC)" \
		BUILD=release \
		ENABLE_RELEASE=1 \
		PIC=1 \
		OS=linux

	emake \
		DMD="${dmd}" \
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
