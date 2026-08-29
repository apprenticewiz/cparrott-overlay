# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop java-pkg-2 shell-completion xdg

DESCRIPTION="Java platform language inspired by Python, Ruby and Smalltalk"
HOMEPAGE="https://groovy-lang.org/"
SRC_URI="mirror://apache/groovy/${PV}/distribution/apache-${PN}-binary-${PV}.zip"
S="${WORKDIR}/${P}"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64 ~arm64 ~ppc64"

# Arch extra/groovy: official apache-groovy-binary zip, GROOVY_HOME under
# /usr/share/groovy, launchers on PATH, bash completions, groovyConsole .desktop.
# Groovy 5 needs JDK 11+ to run.
BDEPEND="app-arch/unzip"
RDEPEND=">=virtual/jre-11:*"

src_prepare() {
	default

	# Arch PKGBUILD: pin GROOVY_HOME and font AA. Without this, startGroovy
	# walks from dirname($0)/.. and would set GROOVY_HOME=/usr.
	local f
	for f in bin/*; do
		[[ -f ${f} ]] || continue
		case ${f} in
			*.bat|*.ico|*_completion) continue ;;
		esac
		local insert
		insert='GROOVY_HOME=/usr/share/groovy'
		insert+='\nexport _JAVA_OPTIONS="-Dawt.useSystemAAFontSettings=gasp ${_JAVA_OPTIONS}"'
		sed -i "s:bin/env sh:bin/env sh\\n${insert}:" "${f}" || die
	done
}

src_compile() {
	:
}

src_install() {
	insinto /usr/share/groovy
	doins -r conf lib

	local f
	for f in bin/*; do
		case ${f} in
			*.bat|*.ico|*_completion) continue ;;
		esac
		dobin "${f}"
	done

	for f in bin/*_completion; do
		# Arch extra/groovy installs these under their upstream names.
		newbashcomp "${f}" "${f##*/}"
	done

	# Arch copies groovy.ico into /usr/bin; keep it as a pixmap instead.
	doicon bin/groovy.ico
	make_desktop_entry groovyConsole "Groovy Console" groovy.ico "Development;Java"

	dodoc LICENSE NOTICE
}
