# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop unpacker xdg

DESCRIPTION="Dyalog APL interpreter"
HOMEPAGE="https://www.dyalog.com/download-zone.htm"
DYALOG_DOWNLOAD="https://www.dyalog.com/uploads/php/download.dyalog.com"
SRC_URI="
	${DYALOG_DOWNLOAD}/download.php?file=$(ver_cut 1-2)/linux_64_${PV}_unicode.x86_64.deb
		-> ${P}-amd64.deb
	https://www.dyalog.com/uploads/documents/Developer_Software_Licence.pdf
		-> dyalog-Developer_Software_Licence.pdf
"
S="${WORKDIR}"

LICENSE="all-rights-reserved"
SLOT="0"
KEYWORDS="-* ~amd64"
IUSE="dotnet odbc"
RESTRICT="bindist mirror strip"
REQUIRED_USE="elibc_glibc"

# Arch's AUR package lists gtk2, libXScrnSaver, and nodejs. The bundled CEF
# binary links the GTK 3 / AT-SPI stack instead; nodejs is shipped inside RIDEapp.
# atk is provided by at-spi2-core. The interpreter does not NEEDED libpython;
# Samples/JSON_APL/*.py are optional demos only.
RDEPEND="
	app-accessibility/at-spi2-core:2
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/nspr
	dev-libs/nss
	media-libs/alsa-lib
	media-libs/mesa
	net-print/cups
	sys-apps/dbus
	dev-build/libtool
	x11-libs/cairo
	x11-libs/gtk+:3
	x11-libs/libX11
	x11-libs/libXcomposite
	x11-libs/libXdamage
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libXrandr
	x11-libs/libxcb
	x11-libs/libxkbcommon
	x11-libs/pango
	dotnet? ( virtual/dotnet-sdk )
	odbc? ( dev-db/unixODBC )
"

QA_PREBUILT="*"

src_unpack() {
	unpack_deb "${P}-amd64.deb"
}

src_install() {
	local dest="/opt/mdyalog/$(ver_cut 1-2)/64/unicode"

	# Keep Dyalog's vendor path: dyalogscript hardcodes it, and mapl
	# locates the install tree via readlink -f.
	dodir "${dest}"
	cp -a "${S}${dest}/." "${ED}${dest}/" || die

	dosym -r "${dest}/mapl" /usr/bin/dyalog
	dosym -r "${dest}/scriptbin/dyalogscript" /usr/bin/dyalogscript

	newdoc "${DISTDIR}/dyalog-Developer_Software_Licence.pdf" LICENSE.pdf
	dodoc usr/share/doc/dyalog-unicode-190/changelog.gz

	doicon "${ED}${dest}/dyalog.svg"
	domenu "${ED}${dest}/dyalog.desktop"
}

pkg_postinst() {
	xdg_pkg_postinst

	elog "Dyalog APL is proprietary software. Review the Developer Software"
	elog "Licence installed as /usr/share/doc/${PF}/LICENSE.pdf."
	elog
	elog "Unregistered use is permitted for non-commercial evaluation."
	elog "To register, put your serial number in ~/.dyalog/serial"
	elog "or export DYALOG_SERIAL."
	elog
	elog "Launch the TTY session with: dyalog"
	elog "The interpreter lives in /opt/mdyalog/$(ver_cut 1-2)/64/unicode"
}
