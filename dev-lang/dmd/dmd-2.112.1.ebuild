# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit flag-o-matic multiprocessing toolchain-funcs

# Arch extra/dmd uses HOST_DMD=ldmd2 (ldc). We bootstrap with gdc instead:
# compiler/src/build.d expects dmd-style flags, so wrap gdc with gdmd.
GDMD_PV="0.26.0"

DESCRIPTION="The D programming language reference compiler"
HOMEPAGE="https://dlang.org/"
SRC_URI="
	https://github.com/dlang/dmd/archive/refs/tags/v${PV}.tar.gz
		-> ${P}.tar.gz
	https://github.com/D-Programming-GDC/gdmd/archive/refs/tags/script-${GDMD_PV}.tar.gz
		-> gdmd-${GDMD_PV}.tar.gz
"
S="${WORKDIR}/dmd-${PV}"

LICENSE="Boost-1.0"
SLOT="0"
KEYWORDS="~amd64"

# The dmd binary is built by gdc and links against gcc's libgphobos, so it
# needs nothing from dev-libs/libphobos to run. libphobos is in turn compiled
# by this dmd, so the dependency has to be a PDEPEND to break the cycle.
RDEPEND=">=sys-devel/gcc-9"
PDEPEND="~dev-libs/libphobos-${PV}"
BDEPEND="
	dev-lang/perl
	>=sys-devel/gcc-9[d]
"

src_prepare() {
	default
	# Arch PKGBUILD: keep VERSION from the tag, not a -dirty git describe.
	sed -i 's/\.git/.nope/' compiler/src/build.d || die
}

# gdmd looks for a 'gdc' binary in the same directory as itself.
host_dmd() {
	local host="${T}/hostd"
	local gdc

	if [[ ! -x ${host}/gdmd ]]; then
		if [[ ${CBUILD} != "${CHOST}" ]] && type -P "${CBUILD}-gdc" >/dev/null; then
			gdc=$(type -P "${CBUILD}-gdc")
		elif type -P "${CHOST}-gdc" >/dev/null; then
			gdc=$(type -P "${CHOST}-gdc")
		else
			gdc=$(type -P gdc) || die "gdc not found; need sys-devel/gcc[d]"
		fi
		mkdir -p "${host}" || die
		ln -s "${gdc}" "${host}/gdc" || die
		cp "${WORKDIR}/gdmd-script-${GDMD_PV}/dmd-script" "${host}/gdmd" || die
		chmod +x "${host}/gdmd" || die
	fi
	echo "${host}/gdmd"
}

src_compile() {
	filter-lto

	local host_dmd
	host_dmd="$(host_dmd)"

	mkdir -p generated || die
	# Arch: $HOST_DMD -ofgenerated/build -g compiler/src/build.d -release -O
	"${host_dmd}" -ofgenerated/build -g compiler/src/build.d -release -O || die

	# Arch: generated/build BUILD=release HOST_DMD=... CXX=c++ ENABLE_RELEASE=1 dmd
	generated/build \
		BUILD=release \
		HOST_DMD="${host_dmd}" \
		CXX="$(tc-getCXX)" \
		ENABLE_RELEASE=1 \
		SYSCONFDIR="${EPREFIX}/etc" \
		-j"$(makeopts_jobs)" \
		dmd || die

	emake -C compiler/docs DMD="${host_dmd}"
}

src_install() {
	local dmd_bin
	dmd_bin=$(find generated/linux/release -name dmd -type f -print -quit)
	[[ -n ${dmd_bin} ]] || die "dmd binary not found"
	dobin "${dmd_bin}"

	local conf="${T}/dmd.conf"
	sed \
		-e "s|@EPREFIX@|${EPREFIX}|g" \
		-e "s|@LIBDIR@|$(get_libdir)|g" \
		"${FILESDIR}/dmd.conf" > "${conf}" || die
	insinto /etc
	doins "${conf}"

	doman generated/docs/man/man1/dmd.1
	if [[ -d generated/docs/man/man5 ]]; then
		doman generated/docs/man/man5/*
	fi

	dodoc LICENSE.txt README.md
}

pkg_postinst() {
	elog "dmd reads ${EPREFIX}/etc/dmd.conf for import and library paths."
	elog "Those paths are provided by dev-libs/libphobos."
}
