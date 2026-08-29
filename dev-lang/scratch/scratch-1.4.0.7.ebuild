# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop toolchain-funcs xdg

DESCRIPTION="Create and share interactive stories, games, music and art"
HOMEPAGE="https://scratch.mit.edu/"
# download.scratch.mit.edu currently has an expired TLS certificate. Void's
# source archive is byte-identical to the one packaged by Arch Linux.
SRC_URI="https://sources.voidlinux.org/${P}/${P}.src.tar.gz"
S="${WORKDIR}/${P}.src"

LICENSE="CC-BY-SA-3.0 GPL-2 MIT"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	dev-lang/squeak-vm
	x11-libs/cairo
	x11-libs/pango
"
DEPEND="${RDEPEND}"
BDEPEND="virtual/pkgconfig"

PATCHES=(
	"${FILESDIR}/${P}-toolchain.patch"
)

src_prepare() {
	default
	gzip -d src/man/scratch.1.gz || die
}

src_compile() {
	emake CC="$(tc-getCC)"
}

src_install() {
	newbin "${FILESDIR}/scratch" scratch

	insinto /usr/lib/scratch
	doins Scratch.image Scratch.ini

	exeinto /usr/lib/scratch/Plugins
	doexe Plugins/so.*

	insinto /usr/share/scratch
	doins -r Help locale Media Projects

	domenu src/scratch.desktop
	doman src/man/scratch.1

	insinto /usr/share/mime/packages
	doins src/scratch.xml

	local size
	for size in 32 48 128; do
		newicon -s "${size}" "src/icons/${size}x${size}/scratch.png" scratch.png
	done

	dodoc README
}
