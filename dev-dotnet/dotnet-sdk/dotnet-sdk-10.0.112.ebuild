# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Source-built .NET SDK 10.0.112 (runtime 10.0.12).
#
# 10.0.112 is the latest servicing SDK that also builds on LoongArch.
# The 10.0.4xx feature band is newer, but Loongson has not published a port of it.
# On ~loong the ebuild applies Loongson's v10.0.112-loongarch64 delta
# (https://github.com/loongson/dotnet) and bootstraps from their 10.0.111 SDK
# plus their previously source-built artifacts. amd64 and arm64 use upstream
# tag v10.0.112 and Microsoft's centos.10-x64 artifact archive.
# ~riscv uses the same upstream tag. Microsoft does not publish a riscv64 SDK
# or artifact archive, so both come from AOSC's 10.0.111 riscv64 packages.
# They must come from the same build: AOSC's analyzers reference Roslyn's
# unofficial version 42.42.42.42, which an officially versioned SDK (5.0.0.0)
# refuses with CS9057.
# ~ppc64 is little-endian only and also uses the upstream tag. The bootstrap
# SDK and artifact archive come from IBM's 10.0.111 linux-ppc64le release
# (https://github.com/IBM/dotnet-s390x). CoreCLR has no ppc64le port, so the
# SDK is built on the Mono runtime.
#
# prep-source-build.sh rewrites portable runtime packs only when it downloads
# the artifact archive. Staging that archive from DISTDIR skips the rewrite,
# so amd64/arm64 run it first and replace the centos RID packs with
# runtime.linux-x64 / linux-arm64 packs from Azure Artifacts. Emerge those
# with FEATURES="-network-sandbox". loong, ppc64 and riscv stay on the staged
# archives; those feeds have no packs for those RIDs.
#
# User variable: DOTNET_VERBOSITY — build log level (default: minimal).

EAPI=8

COMMIT="95017c711e6afc1085133d440e42b4bd78155701"
LOONG_COMMIT="aede5240bac4b2e2b3b64a8e6b11b0d73315c18a"
BOOT_PV="10.0.111"
BOOT_SLOT="$(ver_cut 1-2 "${BOOT_PV}")"
BOOT_RUNTIME_PV="10.0.11"
PSB_VER="${BOOT_PV}-servicing.26373.116"
AOSC_POOL="https://repo.aosc.io/debs/pool/stable/main"
# AOSC keeps only its current version; this release mirrors the riscv files.
RISCV_BOOT_MIRROR="https://github.com/apprenticewiz/cparrott-overlay/releases/download/${PN}-${BOOT_PV}-riscv64"
SDK_SLOT="$(ver_cut 1-2)"
RUNTIME_SLOT="${SDK_SLOT}.12"

LLVM_COMPAT=( 20 )
PYTHON_COMPAT=( python3_{13..14} )

inherit check-reqs flag-o-matic llvm-r2 multiprocessing python-any-r1 toolchain-funcs

DESCRIPTION=".NET is a free, cross-platform, open-source developer platform"
HOMEPAGE="https://dotnet.microsoft.com/
	https://github.com/dotnet/dotnet/"

SRC_URI="
	https://github.com/dotnet/dotnet/archive/refs/tags/v${PV}.tar.gz
		-> ${P}.tar.gz
	amd64? (
		https://builds.dotnet.microsoft.com/dotnet/Sdk/${BOOT_PV}/dotnet-sdk-${BOOT_PV}-linux-x64.tar.gz
		https://builds.dotnet.microsoft.com/dotnet/source-build/Private.SourceBuilt.Artifacts.${PSB_VER}.centos.10-x64.tar.gz
	)
	arm64? (
		https://builds.dotnet.microsoft.com/dotnet/Sdk/${BOOT_PV}/dotnet-sdk-${BOOT_PV}-linux-arm64.tar.gz
		https://builds.dotnet.microsoft.com/dotnet/source-build/Private.SourceBuilt.Artifacts.${PSB_VER}.centos.10-x64.tar.gz
	)
	loong? (
		https://github.com/loongson/dotnet/releases/download/v${BOOT_PV}-loongarch64/dotnet-sdk-${BOOT_PV}-linux-loongarch64.tar.gz
		https://github.com/loongson/dotnet/releases/download/v${BOOT_PV}-loongarch64/Private.SourceBuilt.Artifacts.${PSB_VER}.linux-loongarch64.tar.gz
	)
	ppc64? (
		https://github.com/IBM/dotnet-s390x/releases/download/v${BOOT_PV}/dotnet-sdk-${BOOT_PV}-linux-ppc64le.tar.gz
		https://github.com/IBM/dotnet-s390x/releases/download/v${BOOT_PV}/Private.SourceBuilt.Artifacts.${BOOT_PV}-servicing.linux-ppc64le.tar.gz
	)
	riscv? (
		${AOSC_POOL}/a/aspnetcore-runtime-${BOOT_SLOT}_${BOOT_RUNTIME_PV}-0_riscv64.deb
		${RISCV_BOOT_MIRROR}/aspnetcore-runtime-${BOOT_SLOT}_${BOOT_RUNTIME_PV}-0_riscv64.deb
		${AOSC_POOL}/a/aspnetcore-targeting-pack-${BOOT_SLOT}_${BOOT_RUNTIME_PV}-0_riscv64.deb
		${RISCV_BOOT_MIRROR}/aspnetcore-targeting-pack-${BOOT_SLOT}_${BOOT_RUNTIME_PV}-0_riscv64.deb
		${AOSC_POOL}/d/dotnet-apphost-pack-${BOOT_SLOT}_${BOOT_RUNTIME_PV}-0_riscv64.deb
		${RISCV_BOOT_MIRROR}/dotnet-apphost-pack-${BOOT_SLOT}_${BOOT_RUNTIME_PV}-0_riscv64.deb
		${AOSC_POOL}/d/dotnet-host_${BOOT_RUNTIME_PV}-0_riscv64.deb
		${RISCV_BOOT_MIRROR}/dotnet-host_${BOOT_RUNTIME_PV}-0_riscv64.deb
		${AOSC_POOL}/d/dotnet-hostfxr-${BOOT_SLOT}_${BOOT_RUNTIME_PV}-0_riscv64.deb
		${RISCV_BOOT_MIRROR}/dotnet-hostfxr-${BOOT_SLOT}_${BOOT_RUNTIME_PV}-0_riscv64.deb
		${AOSC_POOL}/d/dotnet-runtime-${BOOT_SLOT}_${BOOT_RUNTIME_PV}-0_riscv64.deb
		${RISCV_BOOT_MIRROR}/dotnet-runtime-${BOOT_SLOT}_${BOOT_RUNTIME_PV}-0_riscv64.deb
		${AOSC_POOL}/d/dotnet-sdk-${BOOT_SLOT}_${BOOT_PV}-0_riscv64.deb
		${RISCV_BOOT_MIRROR}/dotnet-sdk-${BOOT_SLOT}_${BOOT_PV}-0_riscv64.deb
		${AOSC_POOL}/d/dotnet-sdk-${BOOT_SLOT}-source-built-artifacts_${BOOT_PV}-0_riscv64.deb
		${RISCV_BOOT_MIRROR}/dotnet-sdk-${BOOT_SLOT}-source-built-artifacts_${BOOT_PV}-0_riscv64.deb
		${AOSC_POOL}/d/dotnet-targeting-pack-${BOOT_SLOT}_${BOOT_RUNTIME_PV}-0_riscv64.deb
		${RISCV_BOOT_MIRROR}/dotnet-targeting-pack-${BOOT_SLOT}_${BOOT_RUNTIME_PV}-0_riscv64.deb
	)
"
S="${WORKDIR}/${P}"

LICENSE="MIT"
SLOT="${SDK_SLOT}/${RUNTIME_SLOT}"
KEYWORDS="~amd64 ~arm64 ~loong ~ppc64 ~riscv"

# STRIP="llvm-strip" corrupts some executables when using the patchelf hack.
# Be safe and restrict it for source-built too, bug https://bugs.gentoo.org/923430
RESTRICT="splitdebug strip"

CURRENT_NUGETS_DEPEND="
	~dev-dotnet/dotnet-runtime-nugets-${RUNTIME_SLOT}
"
EXTRA_NUGETS_DEPEND="
	~dev-dotnet/dotnet-runtime-nugets-6.0.36
	~dev-dotnet/dotnet-runtime-nugets-7.0.20
	~dev-dotnet/dotnet-runtime-nugets-8.0.30
	~dev-dotnet/dotnet-runtime-nugets-9.0.19
"
# net6/net7/net8/net9 targeting packs in the Gentoo tree have no loongarch,
# ppc64le or riscv64 RID and are not keyworded for those arches. The 10.0.12
# pack set in this overlay is.
PDEPEND="
	${CURRENT_NUGETS_DEPEND}
	amd64? ( ${EXTRA_NUGETS_DEPEND} )
	arm64? ( ${EXTRA_NUGETS_DEPEND} )
"
RDEPEND="
	app-arch/brotli
	app-crypt/mit-krb5:0/0
	dev-libs/icu
	dev-libs/openssl:=
	dev-libs/rapidjson
	dev-util/lttng-ust:=
	sys-devel/gcc:*
	virtual/zlib:0/1
	|| (
		sys-libs/libunwind
		llvm-runtimes/libunwind
	)
"
DEPEND="
	${RDEPEND}
"
BDEPEND="
	${PYTHON_DEPS}
	dev-build/cmake
	dev-libs/libgit2:=
	dev-libs/libxml2
	dev-vcs/git
	net-libs/nodejs
	riscv? (
		app-arch/zstd
		>=dev-libs/openssl-3.4
	)
	$(llvm_gen_dep '
		llvm-core/clang:${LLVM_SLOT}
		llvm-core/lld:${LLVM_SLOT}
		llvm-core/llvm:${LLVM_SLOT}
	')
"
IDEPEND="
	app-eselect/eselect-dotnet
"

CHECKREQS_DISK_BUILD="30G"
CHECKREQS_DISK_USR="1500M"

# Created by dotnet itself:
QA_PREBUILT="
.*/dotnet
.*/ilc
"

# .NET runtime, better to not touch it if they want some specific flags.
QA_FLAGS_IGNORED="
.*/apphost
.*/createdump
.*/dotnet
.*/ilc
.*/libSystem.Globalization.Native.so
.*/libSystem.IO.Compression.Native.so
.*/libSystem.Native.so
.*/libSystem.Net.Security.Native.so
.*/libSystem.Security.Cryptography.Native.OpenSsl.so
.*/libclrgc.so
.*/libclrgcexp.so
.*/libclrjit.so
.*/libcoreclr.so
.*/libcoreclrtraceptprovider.so
.*/libhostfxr.so
.*/libhostpolicy.so
.*/libmscordaccore.so
.*/libmscordbi.so
.*/libnethost.so
.*/singlefilehost
"

check_requirements_locale() {
	if [[ "${MERGE_TYPE}" != binary ]] ; then
		if use elibc_glibc ; then
			local locales
			locales="$(locale -a)"

			if has en_US.utf8 ${locales} ; then
				LC_ALL="en_US.utf8"
			elif has en_US.UTF-8 ${locales} ; then
				LC_ALL="en_US.UTF-8"
			else
				eerror "The locale en_US.utf8 or en_US.UTF-8 is not available."
				eerror "Please generate en_US.UTF-8 before building ${CATEGORY}/${P}."

				die "Could not switch to the en_US.UTF-8 locale."
			fi
		else
			LC_ALL="en_US.UTF-8"
		fi

		export LC_ALL
		einfo "Successfully switched to the ${LC_ALL} locale."
	fi
}

pkg_pretend() {
	# .NET has no big-endian ppc64 RID.
	if use ppc64 && [[ $(tc-endian) == big ]] ; then
		die "${PN} only supports little-endian ppc64 (ppc64le)"
	fi

	check-reqs_pkg_pretend

	check_requirements_locale
}

pkg_setup() {
	check-reqs_pkg_setup
	llvm-r2_pkg_setup
	python-any-r1_pkg_setup

	check_requirements_locale

	if [[ "${MERGE_TYPE}" != binary ]] && { use amd64 || use arm64 ; } ; then
		if has network-sandbox ${FEATURES} ; then
			einfo "amd64/arm64 src_prepare restores portable runtime packs from Azure Artifacts."
			einfo "That step needs network. Re-emerge with FEATURES=\"-network-sandbox\"."
		fi
	fi
}

unpack_aosc_deb() {
	local deb="${1}" dest="${2}" tmp="${T}/deb.${1##*/}" data
	mkdir -p "${tmp}" "${dest}" || die
	ar --output="${tmp}" x "${deb}" || die
	data="$(find "${tmp}" -maxdepth 1 -name 'data.tar.*' -print -quit)" || die
	[[ -n "${data}" ]] || die "${deb##*/} has no data tarball"
	tar -I zstd -xf "${data}" -C "${dest}" || die
	rm -rf "${tmp}" || die
}

src_unpack() {
	unpack "${P}.tar.gz"
	mv "${WORKDIR}/dotnet-${PV}" "${S}" || die
}

src_prepare() {
	if use loong ; then
		eapply "${FILESDIR}/${P}-loongarch64.patch"
	fi

	default

	strip-flags
	filter-flags -Werror=lto-type-mismatch  # Not implemented by Clang, bug 946334
	filter-flags -Wlto-type-mismatch
	filter-lto

	local llvm_prefix="$(get_llvm_prefix -b)"
	export CC="${llvm_prefix}/bin/clang-${LLVM_SLOT}"
	export CXX="${llvm_prefix}/bin/clang++-${LLVM_SLOT}"
	export LD="${llvm_prefix}/bin/lld"

	unset DOTNET_ROOT
	unset NUGET_PACKAGES
	unset CLR_ICU_VERSION_OVERRIDE
	unset USER_CLR_ICU_VERSION_OVERRIDE

	export DOTNET_CLI_TELEMETRY_OPTOUT="1"
	export DOTNET_NUGET_SIGNATURE_VERIFICATION="false"
	export DOTNET_SKIP_FIRST_TIME_EXPERIENCE="1"
	export MSBUILDDISABLENODEREUSE="1"
	export MSBUILDTERMINALLOGGER="off"
	export UseSharedCompilation="false"
	export TreatWarningsAsErrors="false"
	export WarningsNotAsErrors="CS7035"

	local dotnet_sdk_tmp_directory="${WORKDIR}/dotnet-sdk-tmp"
	mkdir -p "${dotnet_sdk_tmp_directory}" || die

	# This should fix the "PackageVersions.props" problem, see "src_compile".
	sed -i build.sh -e "s|/tmp|${dotnet_sdk_tmp_directory}|g" || die

	# This script using comm + sort is broken with newest coreutils >=9.9.
	sed -i ./src/*/eng/build.sh \
		-e "s|actInt=.*|actInt=(-build -pack -publish -restore)|" || die

	# Some .NET SDK build scripts use "nproc" to determine
	# a number of processors. So, we create fake "nproc" command that in fact
	# reports the number of "--jobs" value.
	local fake_bin="${T}/fake_bin"
	mkdir -p "${fake_bin}" || die
	export PATH="${fake_bin}:${PATH}"

	cat <<-EOF > "${fake_bin}/nproc" || die
#!/bin/sh
echo "$(makeopts_jobs)"
EOF
	chmod +x "${fake_bin}/nproc" || die

	# Overwrite "init-compiler" scripts.
	# TODO: Consider - this probably overshadows CCache.
	cat <<EOF > ./init-compiler.sh || die
export CC="${CC}"
export CXX="${CXX}"
export LDFLAGS="${LDFLAGS} -fuse-ld=lld"
export SCAN_BUILD_COMMAND="scan-build"
EOF
	local init_compiler=""
	for init_compiler in diagnostics runtime ; do
		mv "./src/${init_compiler}/eng/common/native/init-compiler.sh"{,.orig} || die
		cp ./init-compiler.sh "./src/${init_compiler}/eng/common/native/" || die
	done

	local boot_rid psb archive_dir="${S}/prereqs/packages/archive"
	if use amd64 ; then
		boot_rid="linux-x64"
	elif use arm64 ; then
		boot_rid="linux-arm64"
	elif use loong ; then
		boot_rid="linux-loongarch64"
	elif use ppc64 ; then
		boot_rid="linux-ppc64le"
	elif use riscv ; then
		boot_rid="linux-riscv64"
	else
		die "no bootstrap SDK for this architecture"
	fi

	mkdir -p "${archive_dir}" || die
	if use riscv ; then
		# AOSC splits the SDK into several debs, all rooted at usr/lib/dotnet.
		local deb sdk_tmp="${T}/riscv-sdk"
		for deb in ${A} ; do
			[[ ${deb} == *_riscv64.deb && ${deb} != *-source-built-artifacts_* ]] || continue
			unpack_aosc_deb "${DISTDIR}/${deb}" "${sdk_tmp}"
		done
		mv "${sdk_tmp}/usr/lib/dotnet" "${S}/.dotnet" || die
		rm -rf "${sdk_tmp}" || die
	else
		mkdir -p "${S}/.dotnet" || die
		tar -xzf "${DISTDIR}/dotnet-sdk-${BOOT_PV}-${boot_rid}.tar.gz" -C "${S}/.dotnet" || die
	fi

	if use loong ; then
		psb="Private.SourceBuilt.Artifacts.${PSB_VER}.linux-loongarch64.tar.gz"
		cp "${DISTDIR}/${psb}" "${archive_dir}/" || die
	elif use ppc64 ; then
		psb="Private.SourceBuilt.Artifacts.${BOOT_PV}-servicing.linux-ppc64le.tar.gz"
		cp "${DISTDIR}/${psb}" "${archive_dir}/" || die
	elif use riscv ; then
		# AOSC ships the linux-riscv64 artifact archive inside a deb.
		local psb_tmp="${T}/riscv-psb" psb_found
		unpack_aosc_deb "${DISTDIR}/dotnet-sdk-${BOOT_SLOT}-source-built-artifacts_${BOOT_PV}-0_riscv64.deb" "${psb_tmp}"
		psb_found="$(find "${psb_tmp}" -name 'Private.SourceBuilt.Artifacts.*.tar.gz' -print -quit)" || die
		[[ -n "${psb_found}" ]] || die "AOSC artifact deb has no source-built archive"
		mv "${psb_found}" "${archive_dir}/" || die
		rm -rf "${psb_tmp}" || die
	else
		psb="Private.SourceBuilt.Artifacts.${PSB_VER}.centos.10-x64.tar.gz"
		cp "${DISTDIR}/${psb}" "${archive_dir}/" || die
	fi

	# Staging the tarball makes prep skip its download, and the portable-pack
	# rewrite only runs inside that download branch. Do it here so binary
	# removal unpacks runtime.${boot_rid} packages instead of centos.10-x64.
	if use amd64 || use arm64 ; then
		local boot_dir="${S}/artifacts/prep-bootstrap"
		mkdir -p "${boot_dir}" "${S}/artifacts/log" || die
		tar -xzf "${archive_dir}/Private.SourceBuilt.Artifacts."*.tar.gz \
			-C "${boot_dir}" PackageVersions.props || die
		cp "${S}/eng/bootstrap/buildBootstrapPreviouslySB.csproj" "${boot_dir}/" || die
		cp "${S}/src/sdk/NuGet.config" "${boot_dir}/" || die

		ebegin "Rewriting portable runtime packs for ${boot_rid}"
		"${S}/.dotnet/dotnet" restore "${boot_dir}/buildBootstrapPreviouslySB.csproj" \
			/bl:"${S}/artifacts/log/prep-bootstrap.binlog" \
			/fileLoggerParameters:LogFile="${S}/artifacts/log/prep-bootstrap.log" \
			/p:ArchiveDir="${archive_dir}/" \
			/p:PortableTargetRid="${boot_rid}"
		local bootstrap_rc=${?}
		rm -rf "${boot_dir}" || die
		eend ${bootstrap_rc} || die "portable runtime pack bootstrap failed; re-emerge with FEATURES=\"-network-sandbox\""
	fi

	local -a prep_args=(
		--no-sdk
		--no-prebuilts
		# amd64/arm64 were rewritten above. loong/ppc64/riscv archives are
		# already the arch-specific set; Azure has no packs for those RIDs.
		--no-bootstrap
	)

	ebegin "Preparing the source-build tree"
	bash ./prep-source-build.sh "${prep_args[@]}"
	eend ${?} || die "prep-source-build failed"
}

src_compile() {
	# Remove .NET leftover files that can be blocking the build.
	# Keep this nonfatal!
	local package_versions_path="/tmp/PackageVersions.props"
	if [[ -f "${package_versions_path}" ]] ; then
		rm "${package_versions_path}" ||
			ewarn "Failed to remove ${package_versions_path}, build may fail!"
	fi

	local -x EXTRA_CFLAGS="${CFLAGS}"
	local -x EXTRA_CXXFLAGS="${CXXFLAGS}"
	local -x EXTRA_LDFLAGS="${LDFLAGS}"

	local source_repository source_version
	if use loong ; then
		source_repository="https://github.com/loongson/dotnet"
		source_version="${LOONG_COMMIT}"
	else
		source_repository="https://github.com/dotnet/dotnet"
		source_version="${COMMIT}"
	fi
	local verbosity="${DOTNET_VERBOSITY:-minimal}"

	local -a buildopts=(
		--source-repository "${source_repository}"
		--source-version "${source_version}"

		--source-build
		--clean-while-building
		--with-system-libs "+brotli+icu+libunwind+rapidjson+zlib+"
		--configuration "Release"
	)
	# Host detection would brand the output gentoo-<version>-<arch>.
	# The bootstrap archives and the portable RID are linux-<arch>.
	if use ppc64 ; then
		# CoreCLR has no ppc64le port.
		buildopts+=(
			--os linux
			--rid linux-ppc64le
			--arch ppc64le
			--use-mono-runtime
		)
	elif use riscv ; then
		buildopts+=(
			--os linux
			--rid linux-riscv64
			--arch riscv64
		)
	fi
	buildopts+=(

		--
		-maxCpuCount:"$(makeopts_jobs)"
		-p:MaxCpuCount="$(makeopts_jobs)"
		-p:ContinueOnPrebuiltBaselineError="true"
		-p:TreatWarningsAsErrors="false"
		-p:WarningsNotAsErrors="CS7035"

		-verbosity:"${verbosity}"
		-p:LogVerbosity="${verbosity}"
		-p:verbosity="${verbosity}"
		-p:MinimalConsoleLogOutput="false"
	)
	einfo "Will build with: ${buildopts[*]}"

	ebegin "Building the .NET SDK ${SDK_SLOT}"
	bash ./build.sh "${buildopts[@]}"
	eend ${?} || die "build failed"
}

src_install() {
	local dest="/usr/$(get_libdir)/${PN}-${SDK_SLOT}"
	dodir "${dest}"

	local archive
	archive="$(find ./artifacts -type f -path '*/Release/dotnet-sdk-*.tar.gz' -print -quit)" || die
	[[ -n "${archive}" ]] || die "could not find the built SDK archive"

	ebegin "Extracting the .NET SDK archive"
	tar xzf "${archive}" -C "${ED}/${dest}"
	eend ${?} || die "extraction failed"

	fperms 0755 "${dest}"
	dosym -r "${dest}/dotnet" "/usr/bin/dotnet-${SDK_SLOT}"

	# Fix permissions again for what is already marked as executable.
	find "${ED}" -type f -executable -exec chmod +x {} + || die
}

pkg_postinst() {
	eselect dotnet update ifunset
}

pkg_postrm() {
	eselect dotnet update ifunset
}
