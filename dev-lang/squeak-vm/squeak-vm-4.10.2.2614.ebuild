# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit flag-o-matic multiprocessing toolchain-funcs

DESCRIPTION="Full-featured implementation of Smalltalk and its programming environment"
HOMEPAGE="https://squeak.org/ http://squeakvm.org/unix/"
SRC_URI="http://squeakvm.org/unix/release/Squeak-${PV}-src.tar.gz"
S="${WORKDIR}/Squeak-${PV}-src"

LICENSE="Apache-2.0 MIT"
SLOT="0"
KEYWORDS="~amd64"

RDEPEND="
	dev-libs/glib:2
	dev-libs/libffi:=
	media-libs/alsa-lib
	media-libs/freetype:2
	media-libs/glu
	media-libs/harfbuzz:=
	media-libs/libglvnd
	media-libs/libpulse
	media-libs/libv4l
	net-libs/libnsl:=
	sys-apps/dbus
	sys-apps/util-linux
	x11-libs/cairo
	x11-libs/libICE
	x11-libs/libSM
	x11-libs/libX11
	x11-libs/libXext
	x11-libs/libXrender
	x11-libs/pango
"
DEPEND="${RDEPEND}"
BDEPEND="
	dev-build/cmake
	virtual/pkgconfig
"

PATCHES=(
	"${FILESDIR}/${P}-modern-toolchain.patch"
)

src_configure() {
	# The 2012-generated VM sources rely on pre-C99 declarations and pointer
	# conversions. GCC 14+ and Clang 16+ otherwise promote these diagnostics
	# to errors. Keep them visible, but do not make them fatal.
	#
	# The spellings differ between compilers, and GCC rejects an unknown
	# -Wno-error= outright, so let flag-o-matic drop what does not apply.
	append-cflags -std=gnu89
	append-cflags $(test-flags-CC \
		-Wno-error=implicit-function-declaration \
		-Wno-error=incompatible-function-pointer-types \
		-Wno-error=incompatible-pointer-types \
		-Wno-error=int-conversion \
		-Wno-error=return-mismatch)
	tc-export CC CXX

	BUILD_DIR="${WORKDIR}/${P}_build"
	mkdir -p "${BUILD_DIR}" || die
	cd "${BUILD_DIR}" || die

	"${S}/unix/cmake/configure" \
		--prefix="${EPREFIX}/usr" \
		--without-quartz \
		--without-CroquetPlugin \
		--with-x \
		--enable-mpg-mmx \
		--CFLAGS="${CFLAGS}" \
		|| die
}

src_compile() {
	cmake --build "${BUILD_DIR}" -j "$(makeopts_jobs)" || die
}

src_install() {
	DESTDIR="${D}" cmake --install "${BUILD_DIR}" || die
	dodoc README unix/doc/{LICENSE,README*}
}
