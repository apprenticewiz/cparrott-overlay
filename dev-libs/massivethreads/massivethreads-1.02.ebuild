# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit flag-o-matic

DESCRIPTION="Lightweight thread library for high-productivity languages"
HOMEPAGE="https://github.com/massivethreads/massivethreads"
SRC_URI="https://github.com/massivethreads/massivethreads/archive/v${PV}.tar.gz
	-> ${P}.tar.gz"

LICENSE="BSD-2"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="sqlite static-libs test"
RESTRICT="!test? ( test )"

# AUR massivethreads 1.02-1: autotools, --prefix=/usr, !lto. Python is
# only used to regenerate tests/Makefile.am; sqlite is optional at
# configure time via sqlite3.h.
RDEPEND="sqlite? ( dev-db/sqlite:3= )"
DEPEND="${RDEPEND}"

src_configure() {
	# AUR options=('!lto')
	filter-lto

	# sqlite is discovered by AC_CHECK_HEADERS, not --enable.
	if ! use sqlite ; then
		export ac_cv_header_sqlite3_h=no
	fi

	econf $(use_enable static-libs static)
}

src_test() {
	emake -C tests build
	emake -C tests check
}

src_install() {
	default
	find "${ED}" -name '*.la' -delete || die
	if ! use static-libs ; then
		find "${ED}" -name '*.a' -delete || die
	fi
	dodoc README.md COPYRIGHT
}
