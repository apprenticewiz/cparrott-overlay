# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

COMMIT="edb6bad6950c787f4b4c7f8ac5f7047ac1e8b984"

inherit autotools flag-o-matic

DESCRIPTION="GNU Smalltalk interpreter and class library"
HOMEPAGE="https://www.gnu.org/software/smalltalk/"
SRC_URI="
	https://github.com/gnu-smalltalk/smalltalk/archive/${COMMIT}.tar.gz
		-> ${P}.tar.gz
"
S="${WORKDIR}/${PN}-${COMMIT}"

LICENSE="GPL-2+ LGPL-2.1+"
SLOT="0"
KEYWORDS="~amd64"
IUSE="test"
RESTRICT="!test? ( test )"

# Keep the feature set aligned with Arch's smalltalk package.  Most modules
# are selected by configure according to the libraries available.
RDEPEND="
	dev-db/sqlite:3
	dev-lang/tcl:0/8.6
	dev-lang/tk:0/8.6
	dev-libs/expat
	dev-libs/gmp:=
	dev-libs/libffi:=
	dev-libs/libltdl:=
	dev-libs/libsigsegv
	media-libs/freeglut
	media-libs/glew:=
	media-libs/glu
	media-libs/libsdl
	media-libs/mesa
	media-libs/sdl-mixer
	net-libs/gnutls:=
	sys-libs/gdbm:=
	sys-libs/ncurses:=
	sys-libs/readline:=
	virtual/zlib:=
	x11-libs/libX11
"
DEPEND="${RDEPEND}"
BDEPEND="
	app-arch/zip
	dev-build/autoconf
	dev-build/automake
	dev-build/libtool
	sys-devel/bison
	sys-devel/flex
	sys-devel/gettext
	dev-util/gperf
	virtual/pkgconfig
"

PATCHES=(
	"${FILESDIR}/${PN}-3.2.91-flex-2.6.patch"
	"${FILESDIR}/${PN}-3.2.91-genbc-multiple-definitions.patch"
	"${FILESDIR}/${PN}-3.2.91-modern-libraries.patch"
)

src_prepare() {
	default
	eautoreconf
}

src_configure() {
	# GCC 14+ promotes several pre-C99 diagnostics in this 2016 source to
	# errors.  Keep the diagnostics visible while building in the last C
	# language mode compatible with the sources.
	append-cflags -std=gnu17
	append-cflags $(test-flags-CC \
		-Wno-error=implicit-function-declaration \
		-Wno-error=incompatible-pointer-types \
		-Wno-error=int-conversion)

	local myeconfargs=(
		--enable-gtk=no
		--enable-libsdl=yes
		--libexecdir="${EPREFIX}/usr/$(get_libdir)/smalltalk"
		--with-imagedir="${EPREFIX}/var/lib/smalltalk"
		--with-readline
		--with-system-libffi
		--with-system-libltdl
		--with-system-libsigsegv
		--with-tcl
		--with-tk
		--with-x
		--without-emacs
	)

	econf "${myeconfargs[@]}"

	# Tcl 8.6 hides the compatibility result field unless requested.
	echo '#define USE_INTERP_RESULT 1' >> config.h || die
}

src_compile() {
	# The image bootstrap and generated-source rules are not parallel-safe.
	emake -j1
}

src_test() {
	emake -j1 check
}

src_install() {
	emake DESTDIR="${D}" install

	# Upstream installs this as an absolute build-directory symlink.
	rm -f "${ED}/usr/share/man/man1/gst-reload.1" || die
	dosym gst-load.1 /usr/share/man/man1/gst-reload.1

	# gst-browser requires the disabled, obsolete GTK+ 2 bindings.
	rm -f \
		"${ED}/usr/bin/gst-browser" \
		"${ED}/usr/share/man/man1/gst-browser.1" || die

	einstalldocs
}
