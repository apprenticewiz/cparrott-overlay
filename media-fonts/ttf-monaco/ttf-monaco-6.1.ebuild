# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit font

DESCRIPTION="Monaco monospaced typeface with extra special characters"
HOMEPAGE="https://github.com/taodongl/monaco.ttf"
SRC_URI="https://github.com/taodongl/monaco.ttf/raw/master/monaco.ttf -> ${P}.ttf"
S="${WORKDIR}"

LICENSE="all-rights-reserved"
SLOT="0"
KEYWORDS="~amd64"
RESTRICT="bindist mirror"

FONT_SUFFIX="ttf"

src_unpack() {
	cp "${DISTDIR}/${A}" "${S}/Monaco.ttf" || die
}
