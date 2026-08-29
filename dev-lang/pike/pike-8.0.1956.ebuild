# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit flag-o-matic multiprocessing

DESCRIPTION="Dynamic programming language with a syntax similar to Java and C"
HOMEPAGE="https://pike.lysator.liu.se/"
SRC_URI="https://pike.lysator.liu.se/pub/pike/all/${PV}/Pike-v${PV}.tar.gz -> ${P}.tar.gz"
S="${WORKDIR}/Pike-v${PV}"

LICENSE="GPL-2 LGPL-2.1 MPL-1.1"
SLOT="0"
KEYWORDS="~amd64"
IUSE="fftw fuse glut gtk mysql odbc postgres sane sdl"

# AUR pike 8.0.1956-2: gmp/zlib/nettle/pcre always; optional modules are
# makedepends that configure auto-detects.  USE flags keep that optional
# and pass --without-* so a disabled flag cannot silently link.
RDEPEND="
	dev-libs/gmp:=
	dev-libs/libpcre:=
	dev-libs/nettle:=
	virtual/libcrypt:=
	virtual/zlib:=
	fftw? ( sci-libs/fftw:3.0= )
	fuse? ( sys-fs/fuse:0= )
	glut? ( media-libs/freeglut )
	gtk? (
		gnome-base/librsvg:=
		x11-libs/gtk+:2
		x11-libs/libXpm
	)
	mysql? ( dev-db/mariadb-connector-c:= )
	odbc? ( dev-db/libiodbc )
	postgres? ( dev-db/postgresql:= )
	sane? ( media-gfx/sane-backends )
	sdl? (
		media-libs/libsdl
		media-libs/sdl-mixer
	)
"
DEPEND="${RDEPEND}"
BDEPEND="
	gtk? ( virtual/pkgconfig )
	sdl? ( virtual/pkgconfig )
"

src_prepare() {
	default

	# C23 makes true/false keywords; AUR rewrites these socket-option temps.
	sed -i \
		-e 's/true/enable/' \
		-e 's/false/disable/' \
		src/modules/HTTPLoop/requestobject.c || die
}

src_compile() {
	# LTO makes configure conclude it is building on macOS (AUR).
	filter-lto
	append-cflags -std=gnu90

	local -a myconf=(
		--prefix="${EPREFIX}/usr"
		# configure appends an ABI suffix when libdir is the autoconf
		# default or when "${libdir}64" exists, so asking for /usr/lib
		# silently yields /usr/lib64 and bakes that path into the
		# interpreter's master cookie. Name the real libdir instead.
		--libdir="${EPREFIX}/usr/$(get_libdir)"
		--disable-make.conf
		--without-GTK
		--without-java
		--without-ffmpeg
		--with-gif
		--with-gmp
		$(use_with mysql)
		$(use_with postgres)
		$(use_with odbc)
		$(use_with sane)
		$(use_with fftw)
		$(use_with fuse)
		$(usex gtk --with-GTK2 --without-GTK2)
		$(usex sdl --with-SDL --without-SDL)
	)

	# GLUT's configure disables the module whenever the flag is given at
	# all, so it can only be enabled by saying nothing.
	use glut || myconf+=( --without-GLUT )

	# The top-level Makefile only sequences configure, bootstrap and
	# install, and it is not -j safe (AUR uses options=('!makeflags')).
	# Upstream's MAKE_PARALLEL is the knob for the actual compile.
	emake -j1 MAKE_PARALLEL="-j$(makeopts_jobs)" CONFIGUREARGS="${myconf[*]}"
}

src_install() {
	# install.pike defaults doc_prefix to ${prefix}/doc/pike.
	emake -j1 \
		buildroot="${D}" \
		INSTALLARGS="--traditional doc_prefix=${EPREFIX}/usr/share/doc/${PF}/refdoc" \
		install_nodoc

	doman man/pike.1
	dodoc README CHANGES
}
