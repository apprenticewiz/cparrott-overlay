# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit flag-o-matic multiprocessing toolchain-funcs

DESCRIPTION="The D programming language reference compiler"
HOMEPAGE="https://dlang.org/"
SRC_URI="
	https://github.com/dlang/dmd/archive/refs/tags/v${PV}.tar.gz
		-> ${P}.tar.gz
"
S="${WORKDIR}/dmd-${PV}"

LICENSE="Boost-1.0"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND=">=sys-devel/gcc-9"
DEPEND="${RDEPEND}"
PDEPEND="~dev-libs/libphobos-${PV}"
BDEPEND="
	|| (
		dev-lang/dmd-bootstrap
		<dev-lang/dmd-${PV}
	)
"

src_prepare() {
	default
	# Arch PKGBUILD: keep VERSION from the tag, not a -dirty git describe.
	sed -i 's/\.git/.nope/' compiler/src/build.d || die
}

host_dmd() {
	if [[ -x ${BROOT}/usr/bin/dmd ]]; then
		echo "${BROOT}/usr/bin/dmd"
	elif [[ -x ${BROOT}/usr/lib/dmd-bootstrap/bin/dmd ]]; then
		echo "${BROOT}/usr/lib/dmd-bootstrap/bin/dmd"
	else
		die "Need dev-lang/dmd or dev-lang/dmd-bootstrap"
	fi
}

src_compile() {
	filter-lto

	local host_dmd
	host_dmd="$(host_dmd)"

	# A single build, as in the Arch PKGBUILD. dmd links Druntime and Phobos
	# statically, so this binary carries the host compiler's runtime and never
	# loads libphobos2.so; a self-host stage would have nothing to relink.
	mkdir -p generated || die
	# Arch: $HOST_DMD -ofgenerated/build -g compiler/src/build.d -release -O
	"${host_dmd}" -ofgenerated/build -g compiler/src/build.d -release -O || die

	generated/build \
		BUILD=release \
		HOST_DMD="${host_dmd}" \
		CXX="$(tc-getCXX)" \
		ENABLE_RELEASE=1 \
		SYSCONFDIR="${EPREFIX}/etc" \
		-j"$(makeopts_jobs)" \
		dmd || die

	# Arch builds the man pages with HOST_DMD too: the generator imports
	# object.d, and this release's runtime does not exist yet.
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
	elog "dmd reads ${EPREFIX}/etc/dmd.conf for its import and library paths."
	elog "Druntime and Phobos come from the matching dev-libs/libphobos slot."
}
