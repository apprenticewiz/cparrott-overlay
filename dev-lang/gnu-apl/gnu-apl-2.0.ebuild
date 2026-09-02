# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PYTHON_COMPAT=( python3_{11..14} )

inherit python-single-r1 toolchain-funcs

DESCRIPTION="GNU interpreter for the APL programming language"
HOMEPAGE="https://www.gnu.org/software/apl/"
SRC_URI="mirror://gnu/apl/apl-${PV}.tar.gz"
S="${WORKDIR}/apl-${PV}"

LICENSE="GPL-3+"
SLOT="0"
KEYWORDS="~amd64"
IUSE="doc erlang fftw gsl gtk3 libapl +pcre2 +png postgresql python-module +sqlite3 static-libs X"

REQUIRED_USE="
	erlang? ( libapl )
	python-module? ( ${PYTHON_REQUIRED_USE} )
"

RDEPEND="
	sys-libs/ncurses:=
	fftw? ( sci-libs/fftw:3.0= )
	gsl? ( >=sci-libs/gsl-2.7:= )
	gtk3? ( x11-libs/gtk+:3 )
	pcre2? ( dev-libs/libpcre2:=[pcre32] )
	png? (
		media-libs/libpng:=
		virtual/zlib:=
	)
	postgresql? ( dev-db/postgresql:= )
	python-module? ( ${PYTHON_DEPS} )
	sqlite3? ( dev-db/sqlite:3 )
	erlang? ( dev-lang/erlang )
	X? (
		x11-libs/libX11
		x11-libs/libxcb
	)
"
DEPEND="${RDEPEND}"
BDEPEND="
	dev-vcs/subversion
	doc? (
		|| (
			app-office/libreoffice
			app-office/libreoffice-bin
		)
	)
	gtk3? ( virtual/pkgconfig )
	python-module? ( virtual/pkgconfig )
"

pkg_setup() {
	use python-module && python-single-r1_pkg_setup
}

src_prepare() {
	default

	# HOWTOs writes intermediate HTML through /tmp, which the sandbox blocks.
	sed -i \
		-e 's|> /tmp/$@ ;| > $@.tmp ;|' \
		-e 's|mv -f /tmp/$@|mv -f $@.tmp|' \
		-e '/APL-on-Macintosh\.pdf/d' \
		-e '/Parallel-APL\.pdf/d' \
		HOWTOs/Makefile.am HOWTOs/Makefile.in || die

	if use doc; then
		# Give LibreOffice a profile under HOME instead of writing into
		# /usr/lib*/libreoffice/share/uno_packages.
		sed -i \
			-e 's|lowriter --headless --convert-to pdf $<|soffice --headless --norestore --nolockcheck -env:UserInstallation=file://$$HOME/lo-profile --convert-to pdf --outdir . $<|' \
			HOWTOs/Makefile.am HOWTOs/Makefile.in || die
	else
		# The PDF is only a make all extra; it is not in dist_doc_DATA.
		sed -i -e '/^all: LApack-primer\.pdf$/d' \
			HOWTOs/Makefile.am HOWTOs/Makefile.in || die
	fi
}

src_compile() {
	if use doc; then
		# LibreOffice still probes its system uno_packages dir; pretend that
		# write succeeded so the sandbox does not fail the build.
		addpredict /usr/$(get_libdir)/libreoffice
		mkdir -p "${T}/lo-home" || die
		local -x HOME="${T}/lo-home"
		local -x SAL_USE_VCLPLUGIN=svp
		local -x SAL_DISABLE_OPENCL=1
	fi
	default
}

src_configure() {
	# These libraries are auto-detected and have no --with/--without switch.
	# Negative cache values keep disabled USE flags deterministic.
	if ! use fftw; then
		local -x ac_cv_header_fftw3_h=no
	fi
	if ! use gsl; then
		local -x ac_cv_lib_gslcblas_cblas_cgemv=no
		local -x ac_cv_header_gsl_gsl_blas_h=no
		local -x ac_cv_lib_gsl_gsl_linalg_QL_decomp=no
		local -x ac_cv_header_gsl_gsl_version_h=no
	fi
	if ! use png; then
		local -x ac_cv_header_png_h=no
		local -x ac_cv_header_zlib_h=no
	fi

	local myeconfargs=(
		$(use_enable static-libs static)
		$(use_with erlang)
		$(use_with libapl)
		$(use_with python-module)
		$(use_with gtk3)
		$(use_with pcre2 pcre)
		$(use_with sqlite3)
		$(use_with postgresql)
		$(use_with X x)
		CXX_WERROR=no
	)

	econf "${myeconfargs[@]}"
}

src_install() {
	default

	if use doc; then
		dodoc HOWTOs/{APL-on-Macintosh,Parallel-APL,LApack-primer}.pdf
	fi

	find "${ED}" -name '*.la' -delete || die
}
