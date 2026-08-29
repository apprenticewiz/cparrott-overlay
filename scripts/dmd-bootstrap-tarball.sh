#!/usr/bin/env bash
# Build a dmd-bootstrap distfile from source, using gdc as the host compiler.
# Needs sys-devel/gcc[d] and perl; nothing from dev-lang/dmd.
#
#   mkbootstrap-tarball.sh [outdir]
#
# Override PV, PHOBOS_PV, GDMD_PV, GDC or JOBS in the environment if needed.
set -euo pipefail

PV="${PV:-2.112.1}"
PHOBOS_PV="${PHOBOS_PV:-2.112.0}"
GDMD_PV="${GDMD_PV:-0.26.0}"
GDC="${GDC:-gdc}"
JOBS="${JOBS:-$(nproc)}"
OUTDIR="${1:-${PWD}}"

die() {
	echo "error: $*" >&2
	exit 1
}

case "$(uname -m)" in
	x86_64) ARCH=amd64 ;;
	aarch64) ARCH=arm64 ;;
	*) die "unsupported architecture $(uname -m)" ;;
esac

command -v "${GDC}" >/dev/null || die "${GDC} not found; emerge sys-devel/gcc with USE=d"
command -v perl >/dev/null || die "perl not found; gdmd is a perl script"
command -v curl >/dev/null || die "curl not found"

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

fetch() {
	local url=$1 out=$2
	if [[ -n ${DISTDIR:-} && -f ${DISTDIR}/${out} ]]; then
		cp "${DISTDIR}/${out}" "${work}/${out}"
		return
	fi
	echo ">>> Fetching ${out}"
	curl -fL --retry 3 -o "${work}/${out}" "${url}"
}

fetch "https://github.com/dlang/dmd/archive/refs/tags/v${PV}.tar.gz" \
	"dmd-${PV}.tar.gz"
fetch "https://github.com/dlang/phobos/archive/refs/tags/v${PHOBOS_PV}.tar.gz" \
	"phobos-${PHOBOS_PV}.tar.gz"
fetch "https://github.com/D-Programming-GDC/gdmd/archive/refs/tags/script-${GDMD_PV}.tar.gz" \
	"gdmd-${GDMD_PV}.tar.gz"

for t in "dmd-${PV}" "phobos-${PHOBOS_PV}" "gdmd-${GDMD_PV}"; do
	tar -C "${work}" -xzf "${work}/${t}.tar.gz"
done

dmd_src="${work}/dmd-${PV}"
phobos_src="${work}/phobos-${PHOBOS_PV}"

# gdmd translates dmd-style flags into gdc flags and looks for a 'gdc' binary
# in its own directory.
hostd="${work}/hostd"
mkdir -p "${hostd}"
ln -s "$(command -v "${GDC}")" "${hostd}/gdc"
install -m755 "${work}/gdmd-script-${GDMD_PV}/dmd-script" "${hostd}/gdmd"

# Keep the reported version from the tag rather than a -dirty git describe.
sed -i 's/\.git/.nope/' "${dmd_src}/compiler/src/build.d"

echo ">>> Building dmd with ${GDC}"
cd "${dmd_src}"
mkdir -p generated
"${hostd}/gdmd" -ofgenerated/build -g compiler/src/build.d -release -O
generated/build \
	BUILD=release \
	HOST_DMD="${hostd}/gdmd" \
	CXX="${CXX:-c++}" \
	ENABLE_RELEASE=1 \
	-j"${JOBS}" \
	dmd

dmd_bin="$(find generated -name dmd -type f -print -quit)"
[[ -n ${dmd_bin} ]] || die "dmd binary not built"
dmd_bin="${dmd_src}/${dmd_bin#./}"

echo ">>> Building druntime and phobos with the new dmd"
make -C "${dmd_src}/druntime" -j"${JOBS}" \
	DMD="${dmd_bin}" BUILD=release ENABLE_RELEASE=1 PIC=1 OS=linux
make -C "${phobos_src}" -j"${JOBS}" \
	DMD="${dmd_bin}" DMD_DIR="${dmd_src}" BUILD=release ENABLE_RELEASE=1 PIC=1 OS=linux

echo ">>> Assembling tarball"
pkg="${work}/dmd-bootstrap-${PV}"
mkdir -p "${pkg}/bin" "${pkg}/include/dlang/dmd" "${pkg}/lib"

install -m755 "${dmd_bin}" "${pkg}/bin/dmd"

cp -r "${phobos_src}"/*.d "${phobos_src}"/etc "${phobos_src}"/std \
	"${pkg}/include/dlang/dmd/"
cp -r "${dmd_src}"/druntime/import/* "${pkg}/include/dlang/dmd/"

while IFS= read -r -d '' f; do
	[[ ${f} == *.so.a ]] && continue
	cp -P "${f}" "${pkg}/lib/"
done < <(find \
	"${dmd_src}/generated/linux/release" \
	"${phobos_src}/generated/linux/release" \
	\( -name '*.a' -o -name '*.so*' \) ! -name '*.o' -print0)

mkdir -p "${OUTDIR}"
tarball="${OUTDIR}/dmd-bootstrap-${PV}-${ARCH}.tar.xz"
tar -C "${work}" -cJf "${tarball}" "dmd-bootstrap-${PV}"
echo "Wrote ${tarball}"
