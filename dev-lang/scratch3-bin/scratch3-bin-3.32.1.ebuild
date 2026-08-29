# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Matches scratch-desktop 3.32.x package.json. AUR scratch3-bin 3.29.1 used
# Arch's electron13-bin; that Windows installer URL 404s, and 3.32 needs
# Electron 42, not 13.
ELECTRON_PV="42.0.1"

inherit chromium-2 desktop optfeature xdg

DESCRIPTION="Scratch 3.0 as a self-contained Electron desktop application"
HOMEPAGE="https://scratch.mit.edu/
	https://github.com/scratchfoundation/scratch-desktop"
SRC_URI="
	https://downloads.scratch.mit.edu/desktop/Scratch%20${PV}%20Setup.exe
		-> scratch-desktop-${PV}-Setup.exe
	https://raw.githubusercontent.com/scratchfoundation/scratch-desktop/v$(ver_cut 1-2).0/LICENSE
		-> scratch-desktop-${PV}-LICENSE
	amd64? (
		https://github.com/electron/electron/releases/download/v${ELECTRON_PV}/electron-v${ELECTRON_PV}-linux-x64.zip
			-> electron-${ELECTRON_PV}-linux-amd64.zip
	)
	arm64? (
		https://github.com/electron/electron/releases/download/v${ELECTRON_PV}/electron-v${ELECTRON_PV}-linux-arm64.zip
			-> electron-${ELECTRON_PV}-linux-arm64.zip
	)
"
S="${WORKDIR}/${PN}"

LICENSE="AGPL-3 BSD MIT BSD-2 Apache-2.0 ISC MPL-2.0"
SLOT="0"
KEYWORDS="-* ~amd64 ~arm64"
RESTRICT="strip splitdebug"

RDEPEND="
	>=app-accessibility/at-spi2-core-2.46.0:2
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/nspr
	dev-libs/nss
	media-libs/alsa-lib
	media-libs/mesa
	net-print/cups
	sys-apps/dbus
	virtual/udev
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
"
BDEPEND="
	app-arch/unzip
	|| (
		>=app-arch/7zip-24.09
		app-arch/p7zip
	)
"
QA_PREBUILT="*"

src_unpack() {
	mkdir -p "${S}" || die
	cd "${S}" || die

	local zip
	if use amd64; then
		zip="electron-${ELECTRON_PV}-linux-amd64.zip"
	elif use arm64; then
		zip="electron-${ELECTRON_PV}-linux-arm64.zip"
	else
		die "No Electron zip for this architecture"
	fi
	unpack "${zip}"

	local cmd7z
	if type -P 7zz >/dev/null; then
		cmd7z=7zz
	elif type -P 7z >/dev/null; then
		cmd7z=7z
	else
		cmd7z=7za
	fi

	# electron-builder NSIS: payload is $PLUGINSDIR/app-32.7z, not a
	# top-level resources/ directory like the old 3.29.1 installer.
	"${cmd7z}" x -tnsis \
		"${DISTDIR}/scratch-desktop-${PV}-Setup.exe" \
		"-o${T}/nsis" \
		'$PLUGINSDIR/app-32.7z' || die
	local app7z
	app7z="$(find "${T}/nsis" -name 'app-32.7z' -print -quit)"
	[[ -n ${app7z} ]] || die "NSIS payload app-32.7z not found"
	"${cmd7z}" x "${app7z}" 'resources/' "-o${S}" || die
	cp "${DISTDIR}/scratch-desktop-${PV}-LICENSE" "${WORKDIR}/LICENSE" || die
}

src_configure() {
	chromium_suid_sandbox_check_kernel_config
}

src_prepare() {
	default

	rm -f resources/default_app.asar || die
	# Windows leftover from the installer payload
	find resources -type f \( -name '*.exe' -o -name '*.dll' \) -delete || die
	chmod -R a+rX resources || die

	mv electron scratch3 || die
}

src_install() {
	insinto /opt/${PN}
	doins -r .

	local f
	for f in scratch3 chrome-sandbox chrome_crashpad_handler \
		libEGL.so libGLESv2.so libffmpeg.so libvk_swiftshader.so \
		libvulkan.so.1
	do
		[[ -e ${ED}/opt/${PN}/${f} ]] && fperms +x /opt/${PN}/${f}
	done
	fowners root /opt/${PN}/chrome-sandbox
	fperms 4711 /opt/${PN}/chrome-sandbox

	dosym -r /opt/${PN}/scratch3 /usr/bin/scratch3

	domenu "${FILESDIR}/scratch3.desktop"
	newicon -s scalable "${FILESDIR}/ScratchDesktop.svg" scratch3.svg
	newicon -s scalable -c mimetypes "${FILESDIR}/cathead.svg" \
		x-scratch3-sprite.svg

	insinto /usr/share/mime/packages
	doins "${FILESDIR}/scratch3.xml"

	newdoc "${WORKDIR}/LICENSE" LICENSE.scratch-desktop
	dodoc LICENSE LICENSES.chromium.html
}

pkg_postinst() {
	xdg_pkg_postinst
	optfeature "opening http(s) links from Scratch" x11-misc/xdg-utils
	elog "This is an unofficial Linux build: Scratch's Windows desktop assets"
	elog "running on Electron ${ELECTRON_PV}. It is not supported by the"
	elog "Scratch Foundation. Scratch 1.4 remains available as dev-lang/scratch."
}
