#!/usr/bin/env bash
# Build the fetch-restricted Bazel dependency bundle used by dev-lang/mojo.
# The compiler's Bazel graph pins and patches its own LLVM, sysroot, Python
# wheels, and build rules.  Keeping those repositories in one target-specific
# bundle lets Portage build with network-sandbox enabled.
#
# Usage:
#   mojo-bazel-vendor.sh [output-directory]
#
# Override PV, COMMIT, BAZEL_COMMIT, or JOBS in the environment if updating.
set -euo pipefail

PV="${PV:-1.1.0_pre20260818}"
COMMIT="${COMMIT:-e41ef364252c5325e2473300f657ba40bb1187e7}"
BAZEL_COMMIT="${BAZEL_COMMIT:-46c5e789f84c7bf4ba1edb105eefa7bc4ebc841b}"
JOBS="${JOBS:-$(nproc)}"
OUTDIR="${1:-${PWD}}"

die() {
	echo "error: $*" >&2
	exit 1
}

case "$(uname -m)" in
	x86_64)
		ARCH=amd64
		BAZEL_PLATFORM=linux
		;;
	aarch64)
		ARCH=arm64
		BAZEL_PLATFORM=linux_arm64
		;;
	*)
		die "unsupported architecture $(uname -m)"
		;;
esac

for command in curl tar zstd; do
	command -v "${command}" >/dev/null || die "${command} not found"
done

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

source_tar="${work}/mojo-${PV}.tar.gz"
bazel="${work}/bazel"

echo ">>> Fetching Modular source ${COMMIT}"
curl -fL --retry 3 \
	-o "${source_tar}" \
	"https://github.com/modular/modular/archive/${COMMIT}.tar.gz"

echo ">>> Fetching pinned Bazel ${BAZEL_COMMIT}"
curl -fL --retry 3 \
	-o "${bazel}" \
	"https://storage.googleapis.com/bazel-builds/artifacts/${BAZEL_PLATFORM}/${BAZEL_COMMIT}/bazel"
chmod +x "${bazel}"

tar -C "${work}" -xzf "${source_tar}"
src="${work}/modular-${COMMIT}"
mkdir -p "${src}/build" "${work}/home" "${work}/repository-cache"
# .bazelrc imports this generated file.  The upstream wrapper normally writes
# it, but the helper invokes the pinned Bazel binary directly.
: > "${src}/build/wrapper.bazelrc"

common_args=(
	--repository_cache="${work}/repository-cache"
	--//:use_prebuilt_mojo_toolchain=false
	--jobs="${JOBS}"
)

echo ">>> Resolving //KGEN:mojo dependencies"
(
	cd "${src}"
	HOME="${work}/home" "${bazel}" \
		--output_user_root="${work}/bazel-root" \
		fetch "${common_args[@]}" //KGEN:mojo
)

echo ">>> Vendoring //KGEN:mojo dependencies"
(
	cd "${src}"
	HOME="${work}/home" "${bazel}" \
		--output_user_root="${work}/bazel-root" \
		vendor \
		--vendor_dir="${work}/mojo-vendor" \
		"${common_args[@]}" \
		//KGEN:mojo
)

# Bazel's vendor command intentionally omits generated http_file repositories
# (notably pycross wheel repos), whose archives only live in the repository
# cache, so ship the cache alongside the vendor directory.
mv "${work}/repository-cache" "${work}/mojo-cache"

mkdir -p "${OUTDIR}"
bundle="${OUTDIR}/mojo-${PV}-bazel-vendor-${ARCH}.tar.zst"
echo ">>> Writing ${bundle}"
# The lockfile written above is what lets Bazel resolve modules from the
# vendored registry instead of bcr.bazel.build.
tar -I 'zstd -T0' -C "${work}" -cf "${bundle}" \
	mojo-vendor mojo-cache -C "${src}" MODULE.bazel.lock
echo "Wrote ${bundle}"
