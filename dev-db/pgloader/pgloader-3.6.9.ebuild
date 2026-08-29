# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit readme.gentoo-r1

DESCRIPTION="PostgreSQL data loader with MySQL, SQLite, CSV, and other sources"
HOMEPAGE="https://github.com/dimitri/pgloader https://pgloader.io/"
SRC_URI="https://github.com/dimitri/pgloader/releases/download/v${PV}/pgloader-bundle-${PV}.tgz"
S="${WORKDIR}/pgloader-bundle-${PV}"

LICENSE="POSTGRESQL"
SLOT="0"
KEYWORDS="~amd64"
# The dumped SBCL core is not a normal ELF binary.
RESTRICT="strip"

# Bundle vendors Common Lisp libraries. Native libs are loaded via CFFI.
# qmynd speaks the MySQL protocol in Lisp (no libmysqlclient).
DEPEND="
	dev-db/freetds
	dev-db/sqlite
	dev-libs/libffi
	dev-libs/openssl:=
	virtual/zlib:=
"
RDEPEND="
	${DEPEND}
"
BDEPEND="
	dev-lisp/sbcl
"

PATCHES=(
	"${FILESDIR}/pgloader-3.6.9-sbcl-named-readtables.patch"
)

QA_FLAGS_IGNORED="usr/bin/pgloader"

DOC_CONTENTS="pgloader is a dumped SBCL image. For large loads (for example npanxx), raise the heap at runtime:\\n
pgloader --dynamic-space-size 8192\\n\\n
MySQL/MariaDB source example:\\n
pgloader mysql://USER@localhost/cfb2025 postgresql://cparrott@127.0.0.1/cfb2025\\n"

src_compile() {
	# ASDF / fasl cache must not land in the real HOME.
	export HOME="${T}"
	export XDG_CACHE_HOME="${T}/.cache"

	# save.lisp loads the Quicklisp bundle and dumps an executable.
	# --disable-debugger makes missing deps fail the ebuild instead of hanging.
	local sbcl=(
		sbcl --noinform --non-interactive
		--no-sysinit --no-userinit
		--disable-debugger
		--load save.lisp
	)
	echo "${sbcl[*]}"
	"${sbcl[@]}" || die "sbcl save.lisp failed"
}

src_install() {
	dobin bin/pgloader
	dodoc README.md
	readme.gentoo_create_doc
}

pkg_postinst() {
	readme.gentoo_print_elog
}
