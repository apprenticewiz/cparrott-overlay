# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit font

DESCRIPTION="Apple San Francisco and New York typefaces"
HOMEPAGE="https://developer.apple.com/fonts/"
SRC_URI="
	https://devimages-cdn.apple.com/design/resources/download/SF-Pro.dmg
		-> apple-fonts-SF-Pro-${PV}.dmg
	https://devimages-cdn.apple.com/design/resources/download/SF-Compact.dmg
		-> apple-fonts-SF-Compact-${PV}.dmg
	https://devimages-cdn.apple.com/design/resources/download/SF-Mono.dmg
		-> apple-fonts-SF-Mono-${PV}.dmg
	https://devimages-cdn.apple.com/design/resources/download/NY.dmg
		-> apple-fonts-NY-${PV}.dmg
"
S="${WORKDIR}"

LICENSE="all-rights-reserved"
SLOT="0"
KEYWORDS="~amd64"
RESTRICT="bindist mirror"

BDEPEND="|| (
	app-arch/p7zip
	app-arch/7zip
)"

# Filled in src_install after extraction (otf and possibly ttf).
FONT_SUFFIX="otf"
FONT_S="${S}/fonts"

apple_fonts_7z() {
	if type -P 7z >/dev/null ; then
		7z "${@}"
	elif type -P 7zz >/dev/null ; then
		7zz "${@}"
	else
		die "7z not found (install app-arch/p7zip or app-arch/7zip)"
	fi
}

src_unpack() {
	local archive tmp pkg inner

	mkdir -p "${S}/fonts" "${S}/licenses" || die

	for archive in ${A} ; do
		tmp="${WORKDIR}/extract-${archive%.dmg}"
		mkdir "${tmp}" || die
		pushd "${tmp}" >/dev/null || die

		apple_fonts_7z e -y "${DISTDIR}/${archive}" >/dev/null \
			|| die "failed to extract ${archive}"

		pkg=
		local f
		for f in *.pkg ; do
			if [[ -f "${f}" ]] ; then
				pkg=${f}
				break
			fi
		done
		[[ -n "${pkg}" ]] || die "no installer pkg in ${archive}"

		apple_fonts_7z x -txar -y "${pkg}" >/dev/null \
			|| die "failed to extract xar ${pkg}"

		if [[ -f Resources/English.lproj/License.rtf ]] ; then
			cp Resources/English.lproj/License.rtf \
				"${S}/licenses/LICENSE-${archive%.dmg}.rtf" || die
		fi

		inner=
		for f in *.pkg ; do
			if [[ -d "${f}" ]] ; then
				inner=${f}
				break
			fi
		done
		[[ -n "${inner}" ]] || die "no inner pkg directory in ${archive}"
		pushd "${inner}" >/dev/null || die

		if [[ -e Payload ]] ; then
			apple_fonts_7z x -y Payload >/dev/null \
				|| die "failed to extract Payload from ${archive}"
		fi
		if [[ -e 'Payload~' ]] ; then
			apple_fonts_7z x -y 'Payload~' >/dev/null \
				|| die "failed to extract Payload~ from ${archive}"
		fi
		[[ -d Library/Fonts ]] || die "no Library/Fonts in ${archive}"
		mv Library/Fonts/* "${S}/fonts/" || die

		popd >/dev/null || die
		popd >/dev/null || die
		rm -rf "${tmp}" || die
	done
}

src_install() {
	local suffix files
	local -a present=()

	shopt -s nullglob
	for suffix in otf ttf ttc ; do
		files=( "${FONT_S}"/*.${suffix} )
		if (( ${#files[@]} )) ; then
			present+=( "${suffix}" )
		fi
	done
	shopt -u nullglob

	FONT_SUFFIX="${present[*]}"
	[[ -n ${FONT_SUFFIX} ]] || die "no fonts extracted"

	font_src_install
	dodoc "${S}"/licenses/*
}
