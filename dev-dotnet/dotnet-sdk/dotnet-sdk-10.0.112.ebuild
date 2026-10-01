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
#
# prep-source-build.sh on amd64/arm64 rewrites portable runtime packs and
# contacts Azure Artifacts. Emerge those with FEATURES="-network-sandbox".
# The loong path passes --no-bootstrap and stays on the staged archives.
#
# User variable: DOTNET_VERBOSITY — build log level (default: minimal).

EAPI=8

COMMIT="95017c711e6afc1085133d440e42b4bd78155701"
LOONG_COMMIT="aede5240bac4b2e2b3b64a8e6b11b0d73315c18a"
BOOT_PV="10.0.111"
PSB_VER="${BOOT_PV}-servicing.26373.116"
SDK_SLOT="$(ver_cut 1-2)"
RUNTIME_SLOT="${SDK_SLOT}.12"

LLVM_COMPAT=( 20 )
PYTHON_COMPAT=( python3_{13..14} )

inherit check-reqs flag-o-matic llvm-r2 multiprocessing python-any-r1

DESCRIPTION=".NET is a free, cross-platform, open-source developer platform"
HOMEPAGE="https://dotnet.microsoft.com/
	https://github.com/dotnet/dotnet/"

SRC_URI="
	https://github.com/dotnet/dotnet/archive/refs/tags/v${PV}.tar.gz
		-> ${P}.tar.gz
	amd64? (
		https://builds.dotnet.microsoft.com/dotnet/Sdk/${BOOT_PV}/dotnet-sdk-${BOOT_PV}-linux-x64.tar.gz
	)
	arm64? (
		https://builds.dotnet.microsoft.com/dotnet/Sdk/${BOOT_PV}/dotnet-sdk-${BOOT_PV}-linux-arm64.tar.gz
	)
	loong? (
		https://github.com/loongson/dotnet/releases/download/v${BOOT_PV}-loongarch64/dotnet-sdk-${BOOT_PV}-linux-loongarch64.tar.gz
		https://github.com/loongson/dotnet/releases/download/v${BOOT_PV}-loongarch64/Private.SourceBuilt.Artifacts.${PSB_VER}.linux-loongarch64.tar.gz
	)
	!loong? (
		https://builds.dotnet.microsoft.com/dotnet/source-build/Private.SourceBuilt.Artifacts.${PSB_VER}.centos.10-x64.tar.gz
	)
"
S="${WORKDIR}/${P}"

LICENSE="MIT"
SLOT="${SDK_SLOT}/${RUNTIME_SLOT}"
KEYWORDS="~amd64 ~arm64 ~loong"

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
# net6/net7/net8/net9 targeting packs in the Gentoo tree have no loongarch RID
# and are not keyworded ~loong. The 10.0.12 pack set in this overlay is.
PDEPEND="
	${CURRENT_NUGETS_DEPEND}
	!loong? ( ${EXTRA_NUGETS_DEPEND} )
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
	check-reqs_pkg_pretend

	check_requirements_locale
}

pkg_setup() {
	check-reqs_pkg_setup
	llvm-r2_pkg_setup
	python-any-r1_pkg_setup

	check_requirements_locale

	if [[ "${MERGE_TYPE}" != binary ]] && ! use loong ; then
		if has network-sandbox ${FEATURES} ; then
			einfo "amd64/arm64 prep restores portable runtime packs from Azure Artifacts."
			einfo "If that step is blocked, re-emerge with FEATURES=\"-network-sandbox\"."
		fi
	fi
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
	else
		die "no bootstrap SDK for this architecture"
	fi

	mkdir -p "${S}/.dotnet" "${archive_dir}" || die
	tar -xzf "${DISTDIR}/dotnet-sdk-${BOOT_PV}-${boot_rid}.tar.gz" -C "${S}/.dotnet" || die

	if use loong ; then
		psb="Private.SourceBuilt.Artifacts.${PSB_VER}.linux-loongarch64.tar.gz"
	else
		psb="Private.SourceBuilt.Artifacts.${PSB_VER}.centos.10-x64.tar.gz"
	fi
	cp "${DISTDIR}/${psb}" "${archive_dir}/" || die

	local -a prep_args=(
		--no-sdk
		--no-prebuilts
	)
	if use arm64 ; then
		prep_args+=( --bootstrap-rid linux-arm64 )
	elif use loong ; then
		# Loongson's archive is already the linux-loongarch64 source-built set.
		# Azure feeds do not publish that RID.
		prep_args+=( --no-bootstrap )
	fi

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
