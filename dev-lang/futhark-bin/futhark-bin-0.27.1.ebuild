# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Data-parallel functional array language"
HOMEPAGE="https://futhark-lang.org/"
SRC_URI="https://github.com/diku-dk/futhark/releases/download/v${PV}/futhark-${PV}-linux-x86_64.tar.xz"
S="${WORKDIR}/futhark-${PV}-linux-x86_64"

LICENSE="ISC"
SLOT="0"
KEYWORDS="-* ~amd64"
REQUIRED_USE="elibc_glibc"

RESTRICT="strip"

QA_PREBUILT="usr/bin/futhark"

# The official linux-x86_64 tarball is statically linked. AUR still lists
# ncurses/zlib/gmp from older dynamic builds; they are not needed here.
# GPU/Python backends apply to programs futhark generates, not to this binary.

src_install() {
	emake PREFIX="${ED}/usr" install
	dodoc README.md LICENSE
}

pkg_postinst() {
	elog "The C backend needs a C compiler. Optional backends also need:"
	elog "  OpenCL: virtual/opencl and OpenCL headers"
	elog "  CUDA:   NVIDIA CUDA toolkit"
	elog "  HIP:    ROCm"
	elog "  Python: Python, plus pyopencl for the PyOpenCL backend"
}
