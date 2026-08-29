# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit java-pkg-2

DESCRIPTION="The Scala 3 compiler, also known as Dotty"
HOMEPAGE="https://www.scala-lang.org/"
SRC_URI="https://github.com/scala/scala3/releases/download/${PV}/${P}.tar.gz"
S="${WORKDIR}/${P}"

LICENSE="Apache-2.0"
SLOT="0"
KEYWORDS="~amd64 ~arm64"
IUSE="dotty"

# AUR scala-dotty/scala3 ships the official GitHub compiler tarball (JARs +
# launchers). Building from source pulls Coursier/sbt over the network, which
# Portage's sandbox does not allow. Scala 3.8 needs JDK 17+. Command names
# are versioned (scala3/scalac3/scaladoc3) so this can coexist with
# dev-lang/scala-bin. USE=dotty adds the old dotr/dotc/dotd aliases.
RDEPEND=">=virtual/jre-17:*"

src_prepare() {
	default

	rm -f bin/*.bat libexec/*.bat || die

	# Launchers walk PROG_HOME from $0. Pin it so /usr/bin/scala3 wrappers
	# still find /usr/share/scala3 after any extra symlink hop.
	local f
	for f in bin/*; do
		[[ -f ${f} ]] || continue
		sed -i 's|^#!/usr/bin/env bash|#!/usr/bin/env bash\nPROG_HOME="${PROG_HOME:-/usr/share/scala3}"|' \
			"${f}" || die
	done
}

src_compile() {
	:
}

src_test() {
	PROG_HOME="${S}" bin/scalac -version || die
}

src_install() {
	insinto /usr/share/scala3
	doins VERSION
	doins -r bin lib libexec maven2

	fperms 755 /usr/share/scala3/bin/{scala,scalac,scaladoc}

	dosym ../share/scala3/bin/scala /usr/bin/scala3
	dosym ../share/scala3/bin/scalac /usr/bin/scalac3
	dosym ../share/scala3/bin/scaladoc /usr/bin/scaladoc3

	if use dotty; then
		dosym scala3 /usr/bin/dotr
		dosym scalac3 /usr/bin/dotc
		dosym scaladoc3 /usr/bin/dotd
	fi
}
