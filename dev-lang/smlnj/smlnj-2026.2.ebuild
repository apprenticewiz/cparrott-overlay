# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit multiprocessing toolchain-funcs

DESCRIPTION="Standard ML of New Jersey compiler and libraries"
HOMEPAGE="https://smlnj.org"

# The 110.99.x series in ::gentoo predates the LLVM-based code generator and
# only has MLRISC backends for x86, amd64, ppc and sparc, so it cannot be
# keyworded for arm64.  The modern releases do support Arm64, and they ship a
# single self-contained per-arch archive instead of the ~20 component tarballs
# the old series stitched together.  That archive already carries the boot heap
# and the customised LLVM the code generator links against, so build.sh never
# has to reach the network.
BASE_URI="https://smlnj.org/dist/working/${PV}"
SRC_URI="
	amd64? ( ${BASE_URI}/smlnj-amd64-unix-${PV}.tgz )
	arm64? ( ${BASE_URI}/smlnj-arm64-unix-${PV}.tgz )
"

S="${WORKDIR}/smlnj"

# BSD-3 for SML/NJ proper; the bundled runtime/llvm21 tree is LLVM's licence.
LICENSE="BSD Apache-2.0-with-LLVM-exceptions"
SLOT="0"
KEYWORDS="~amd64 ~arm64"

# heap2exec links the standalone runtime with "ld -r", which needs libz.a.
DEPEND="sys-libs/zlib[static-libs]"
RDEPEND="sys-libs/zlib"
# build-llvm.sh drives CMake through presets, which need 3.23 or later.
# Upstream also lists autoconf, but that is only for asdl when building from a
# git clone; the distribution tarball ships a pre-generated configure.
BDEPEND=">=dev-build/cmake-3.23"

smlnj_dir() { echo "/usr/$(get_libdir)/${PN}"; }

src_prepare() {
	default

	# Respect the toolchain and the user's flags (bug 243886).  -no-pie has
	# to survive: the runtime must be a non-PIE executable.
	sed -e "/^AS[[:space:]]*=/s|as|$(tc-getAS)|" \
		-e "/^CC[[:space:]]*=/s|gcc|$(tc-getCC)|" \
		-e "/^CXX[[:space:]]*=/s|g++|$(tc-getCXX)|" \
		-e "/^CPP[[:space:]]*=/s|gcc|$(tc-getCC)|" \
		-e "/^CFLAGS[[:space:]]*=/{s|-O[0123s]||; s|=|= ${CFLAGS}|}" \
		-e "/^CXX_FLAGS[[:space:]]*=/{s|-O[0123s]||; s|=|= ${CXXFLAGS}|}" \
		-i runtime/objs/mk.* || die

	# build-llvm.sh derives its own job count from nproc and ignores the
	# environment, so pin it to MAKEOPTS just before the value is used.
	sed -i "s|^ALL_TARGETS=|NPROCS=$(makeopts_jobs)\nALL_TARGETS=|" \
		runtime/llvm21/build-llvm.sh || die
}

src_compile() {
	# build.sh has no DESTDIR concept: it bakes its installation directory
	# into the driver scripts it generates.  Build in place and relocate the
	# tree in src_install.  The runtime makefile is not parallel-safe -- its
	# two targets race on the generated ml-sizes.h -- so leave MAKEOPTS out
	# of the environment and let build.sh call make serially, as upstream
	# intends.  Parallelism for the LLVM half is handled in src_prepare.
	./build.sh -verbose || die "build.sh failed"

	# build.sh only warns if the standalone runtime fails to link, which
	# would silently leave heap2exec unusable.
	local suffix
	suffix=$(./bin/.arch-n-opsys) || die
	suffix=${suffix##*HEAP_SUFFIX=}
	[[ -f bin/.run/runx.${suffix} ]] ||
		die "the standalone runtime (runx.${suffix}) did not get built"
}

src_install() {
	local dir="$(smlnj_dir)"
	local prefix_dir="${EPREFIX}${dir}"

	# heap2exec calls llvm-config purely to obtain a fixed list of system
	# libraries.  Resolve it now so the ~180M of LLVM archives that
	# llvm-config insists on validating can be dropped below.
	local syslibs
	syslibs=$(./bin/llvm-config --system-libs) || die
	sed -i -e "s|LIBS=\`\"\$LLVM_CONFIG\" --system-libs\`|LIBS=\"${syslibs}\"|" \
		bin/heap2exec || die
	grep -q "LIBS=\"${syslibs}\"" bin/heap2exec ||
		die "failed to inline the system-library list into heap2exec"

	# Everything else build.sh left behind is only needed to compile SML/NJ
	# itself: LLVM's headers, its CMake package files, its static archives
	# and the standalone llc/llvm-config tools.  heap2obj already has the
	# code generator linked into it.
	rm -rf include lib/cmake bin/llc bin/llvm-config \
		lib/libLLVM*.a lib/libCFGCodeGen.a lib/libHeap2Obj.a || die

	# Rewrite the build-time paths baked in by build.sh's installdriver().
	# lib/pathconfig only uses relative anchors, so the driver scripts under
	# bin/ are the only things that need touching.
	local f
	for f in bin/* bin/.*; do
		[[ -f ${f} && ! -L ${f} ]] || continue
		grep -Iq . "${f}" || continue
		sed -i "s|${S}|${prefix_dir}|g" "${f}" || die
	done

	dodir "${dir}"
	cp -a bin lib "${D}${dir}"/ || die

	# heap2obj is deliberately not linked into /usr/bin: heap2exec resolves
	# it relative to its own bin directory.
	local i
	for i in sml ml-antlr ml-build ml-burg ml-makedepend ml-ulex ml-yacc \
			asdlgen print-cfg heap2exec; do
		[[ -e ${D}${dir}/bin/${i} ]] && dosym "${dir}/bin/${i}" "/usr/bin/${i}"
	done

	dodoc README.md NOTES.md
}
