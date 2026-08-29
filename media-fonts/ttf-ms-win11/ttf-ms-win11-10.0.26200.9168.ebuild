# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit font

DESCRIPTION="Microsoft Windows 11 TrueType fonts"
HOMEPAGE="https://learn.microsoft.com/typography/fonts/"
S="${WORKDIR}"

LICENSE="all-rights-reserved"
SLOT="0"
KEYWORDS="~amd64"
IUSE="japanese korean other sea thai zhcn zhtw"
RESTRICT="bindist fetch mirror"

# Distfiles cannot be mirrored. Place the font files and license.rtf in
# DISTDIR (filenames are case-sensitive; they match the Arch AUR package).

FONT_SUFFIX="ttf ttc"

# Main package (AUR ttf-ms-win11)
TTF_MS_WIN11=(
	arial.ttf arialbd.ttf ariali.ttf arialbi.ttf
	ariblk.ttf
	bahnschrift.ttf
	calibri.ttf calibrib.ttf calibrii.ttf calibriz.ttf
	calibril.ttf calibrili.ttf
	cambria.ttc cambriab.ttf cambriai.ttf cambriaz.ttf
	Candara.ttf Candarab.ttf Candarai.ttf Candaraz.ttf
	Candaral.ttf Candarali.ttf
	comic.ttf comicbd.ttf comici.ttf comicz.ttf
	consola.ttf consolab.ttf consolai.ttf consolaz.ttf
	constan.ttf constanb.ttf constani.ttf constanz.ttf
	corbel.ttf corbelb.ttf corbeli.ttf corbelz.ttf
	corbell.ttf corbelli.ttf
	cour.ttf courbd.ttf couri.ttf courbi.ttf
	framd.ttf framdit.ttf
	Gabriola.ttf
	georgia.ttf georgiab.ttf georgiai.ttf georgiaz.ttf
	impact.ttf
	Inkfree.ttf
	l_10646.ttf
	lucon.ttf
	marlett.ttf
	micross.ttf
	pala.ttf palab.ttf palai.ttf palabi.ttf
	segmdl2.ttf
	SegoeIcons.ttf
	segoepr.ttf segoeprb.ttf
	segoesc.ttf segoescb.ttf
	segoeui.ttf segoeuib.ttf segoeuii.ttf segoeuiz.ttf
	segoeuil.ttf seguili.ttf
	segoeuisl.ttf seguisli.ttf
	seguibl.ttf seguibli.ttf
	seguiemj.ttf
	seguihis.ttf
	seguisb.ttf seguisbi.ttf
	seguisym.ttf
	SegUIVar.ttf
	SitkaVF.ttf SitkaVF-Italic.ttf
	sylfaen.ttf
	symbol.ttf
	tahoma.ttf tahomabd.ttf
	times.ttf timesbd.ttf timesi.ttf timesbi.ttf
	trebuc.ttf trebucbd.ttf trebucit.ttf trebucbi.ttf
	verdana.ttf verdanab.ttf verdanai.ttf verdanaz.ttf
	webdings.ttf
	wingding.ttf
)

TTF_MS_WIN11_JAPANESE=(
	msgothic.ttc
	YuGothR.ttc YuGothB.ttc
	YuGothM.ttc
	YuGothL.ttc
)

TTF_MS_WIN11_KOREAN=(
	malgun.ttf malgunbd.ttf
	malgunsl.ttf
)

TTF_MS_WIN11_SEA=(
	javatext.ttf
	himalaya.ttf
	ntailu.ttf ntailub.ttf
	phagspa.ttf phagspab.ttf
	taile.ttf taileb.ttf
	msyi.ttf
	monbaiti.ttf
	mmrtext.ttf mmrtextb.ttf
	Nirmala.ttc
)

TTF_MS_WIN11_THAI=(
	LeelawUI.ttf LeelaUIb.ttf
	LeelUIsl.ttf
)

TTF_MS_WIN11_ZH_CN=(
	simsun.ttc
	simsunb.ttf
	msyh.ttc msyhbd.ttc
	msyhl.ttc
)

TTF_MS_WIN11_ZH_TW=(
	msjh.ttc msjhbd.ttc
	msjhl.ttc
	mingliub.ttc
)

TTF_MS_WIN11_OTHER=(
	ebrima.ttf ebrimabd.ttf
	gadugi.ttf gadugib.ttf
	mvboli.ttf
)

ttf_ms_win11_required() {
	local f
	for f in license.rtf "${TTF_MS_WIN11[@]}"; do
		echo "${f}"
	done
	use japanese && printf '%s\n' "${TTF_MS_WIN11_JAPANESE[@]}"
	use korean && printf '%s\n' "${TTF_MS_WIN11_KOREAN[@]}"
	use sea && printf '%s\n' "${TTF_MS_WIN11_SEA[@]}"
	use thai && printf '%s\n' "${TTF_MS_WIN11_THAI[@]}"
	use zhcn && printf '%s\n' "${TTF_MS_WIN11_ZH_CN[@]}"
	use zhtw && printf '%s\n' "${TTF_MS_WIN11_ZH_TW[@]}"
	use other && printf '%s\n' "${TTF_MS_WIN11_OTHER[@]}"
}

pkg_nofetch() {
	eerror "Microsoft Windows fonts cannot be downloaded by Portage."
	eerror "Using them outside Windows may be prohibited by Microsoft's EULA;"
	eerror "read that license before installing."
	eerror
	eerror "Get the files from a Windows 11 install (Fonts and license.rtf)"
	eerror "or from a retail ISO:"
	eerror "  https://www.microsoft.com/en-us/software-download/windows11"
	eerror
	eerror "From sources/install.wim on the ISO (app-arch/wimlib):"
	eerror '  wimextract install.wim 1 \'
	eerror '    /Windows/{Fonts/"*".{ttf,ttc},System32/Licenses/neutral/"*"/"*"/license.rtf} \'
	eerror '    --dest-dir fonts'
	eerror
	eerror "Copy every required file (names are case-sensitive) plus license.rtf"
	eerror "into your distfiles directory."
	eerror "This USE combination needs:"
	local f
	while IFS= read -r f; do
		eerror "  ${f}"
	done < <(ttf_ms_win11_required)
}

src_unpack() {
	local f missing=()

	mkdir -p "${S}" || die
	while IFS= read -r f; do
		if [[ -f ${DISTDIR}/${f} ]]; then
			cp "${DISTDIR}/${f}" "${S}/" || die "failed to copy ${f}"
		else
			missing+=( "${f}" )
		fi
	done < <(ttf_ms_win11_required)

	if (( ${#missing[@]} )); then
		eerror "Missing ${#missing[@]} file(s) in ${DISTDIR}:"
		for f in "${missing[@]}"; do
			eerror "  ${f}"
		done
		die "Windows 11 font files are not in DISTDIR; see ebuild comments"
	fi
}

src_install() {
	font_src_install
	dodoc license.rtf
}
