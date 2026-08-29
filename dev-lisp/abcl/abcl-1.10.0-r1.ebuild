# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=9

inherit java-pkg-2

DESCRIPTION="Armed Bear Common Lisp is a Common Lisp implementation for the JVM"
HOMEPAGE="https://abcl.org"
SRC_URI="https://abcl.org/releases/${PV}/abcl-src-${PV}.tar.gz"
S="${WORKDIR}/abcl-src-${PV}"

LICENSE="GPL-2-with-classpath-exception"
SLOT="0"
KEYWORDS="~amd64"

BDEPEND=">=dev-java/ant-1.10.15-r1:0"
# --add-opens in the launcher needs a module-aware JVM, so 11 rather than 1.8.
DEPEND=">=virtual/jdk-11:*"
RDEPEND=">=virtual/jre-11:*"

src_compile() {
	local targets=( abcl.compile abcl.jar )
	eant \
		-Dant.build.javac.source="$(java-pkg_get-source)" \
		-Dant.build.javac.target="$(java-pkg_get-target)" \
		"${targets[@]}"
}

src_install() {
	java-pkg_dojar dist/abcl.jar dist/abcl-contrib.jar

	# ABCL reflects into java.base to implement threads, streams and the FFI,
	# which strong encapsulation refuses by default. Same set upstream passes
	# in ci/create-abcl-properties.bash; without java.lang, (make-thread) dies
	# with InaccessibleObjectException on VirtualThreadFactory.newThread.
	local java_args=(
		-server
		-Xrs
		--add-opens java.base/java.lang=ALL-UNNAMED
		--add-opens java.base/java.io=ALL-UNNAMED
		--add-opens java.base/sun.nio.ch=ALL-UNNAMED
	)
	java-pkg_dolauncher ${PN} --java_args "${java_args[*]}" \
		--main org.armedbear.lisp.Main

	einstalldocs
}
