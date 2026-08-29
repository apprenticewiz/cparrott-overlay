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

# libphobos is built with dmd-bootstrap, so it can be a real build+runtime
# dep here without a cycle. Rebuilds of dmd use the installed compiler;
# a first install pulls dmd-bootstrap.
RDEPEND="
	>=sys-devel/gcc-9
	~dev-libs/libphobos-${PV}
"
DEPEND="${RDEPEND}"
BDEPEND="
	|| (
		>=dev-lang/dmd-${PV}
		~dev-lang/dmd-bootstrap-${PV}
	)
"

src_prepare() {
	default
	# Arch PKGBUILD: keep VERSION from the tag, not a -dirty git describe.
	sed -i 's/\.git/.nope/' compiler/src/build.d || die
}

host_dmd() {
	if has_version -b ">=dev-lang/dmd-${PV}"; then
		echo "${BROOT}/usr/bin/dmd"
	elif [[ -x ${BROOT}/usr/lib/dmd-bootstrap/bin/dmd ]]; then
		echo "${BROOT}/usr/lib/dmd-bootstrap/bin/dmd"
	else
		die "Need >=dev-lang/dmd-${PV} or dmd-bootstrap"
	fi
}

src_compile() {
	filter-lto

	local host_dmd stage1
	host_dmd="$(host_dmd)"

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

	# Self-host: recompile with the stage1 binary. Point it at system
	# libphobos (already installed) via a dmd.conf next to the executable.
	stage1="${T}/stage1"
	mkdir -p "${stage1}" || die
	cp "$(find generated/linux/release -name dmd -type f -print -quit)" "${stage1}/dmd" || die
	chmod +x "${stage1}/dmd" || die
	local inc="${EPREFIX}/usr/include/dlang/dmd"
	local lib="${EPREFIX}/usr/$(get_libdir)"
	local dflags="-I${inc} -L-L${lib} -L--export-dynamic -fPIC"
	printf '%s\n' '[Environment64]' "DFLAGS=${dflags}" > "${stage1}/dmd.conf" || die

	"${stage1}/dmd" -ofgenerated/build -g compiler/src/build.d -release -O || die
	generated/build \
		--force \
		BUILD=release \
		HOST_DMD="${stage1}/dmd" \
		CXX="$(tc-getCXX)" \
		ENABLE_RELEASE=1 \
		SYSCONFDIR="${EPREFIX}/etc" \
		-j"$(makeopts_jobs)" \
		dmd || die

	emake -C compiler/docs DMD="${stage1}/dmd"
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
	elog "Those paths are provided by dev-libs/libphobos, which contains"
	elog "Druntime and the Phobos standard library. Compiling D programs"
	elog "needs it, so emerge it if it is not already installed:"
	elog ""
	elog "    emerge --ask dev-libs/libphobos"
}
