# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Source-built .NET SDK 11.0.100 (runtime 11.0.0).
#
# amd64 and arm64 use upstream tag v11.0.100 and bootstrap from Microsoft's
# 11.0.100-rc.2 SDK and centos.10-x64 artifact archive, the versions that
# eng/Versions.props names.
# loong and ppc64 are not keyworded yet: Loongson has not published a
# v11.0.100-loongarch64 port, and IBM has no 11.0.100 release with
# linux-ppc64le runtime packs. riscv has no 11.0 bootstrap SDK.
#
# prep-source-build.sh rewrites portable runtime packs only when it downloads
# the artifact archive. Staging that archive from DISTDIR skips the rewrite,
# so src_prepare runs it first and replaces the centos RID packs with
# runtime.linux-x64 / linux-arm64 packs from Azure Artifacts. Emerge with
# FEATURES="-network-sandbox".
#
# User variable: DOTNET_VERBOSITY — build log level (default: minimal).

EAPI=8

COMMIT="297acf930fb0f5c07fd4e51d78e521b4ad2e5d1f"
BOOT_PV="11.0.100-rc.2.26504.105"
SDK_SLOT="$(ver_cut 1-2)"
RUNTIME_SLOT="${SDK_SLOT}.0"

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
		https://builds.dotnet.microsoft.com/dotnet/source-build/Private.SourceBuilt.Artifacts.${BOOT_PV}.centos.10-x64.tar.gz
	)
	arm64? (
		https://builds.dotnet.microsoft.com/dotnet/Sdk/${BOOT_PV}/dotnet-sdk-${BOOT_PV}-linux-arm64.tar.gz
		https://builds.dotnet.microsoft.com/dotnet/source-build/Private.SourceBuilt.Artifacts.${BOOT_PV}.centos.10-x64.tar.gz
	)
"
S="${WORKDIR}/${P}"

LICENSE="MIT"
SLOT="${SDK_SLOT}/${RUNTIME_SLOT}"
KEYWORDS="~amd64 ~arm64"

# STRIP="llvm-strip" corrupts some executables when using the patchelf hack.
# Be safe and restrict it for source-built too, bug https://bugs.gentoo.org/923430
RESTRICT="splitdebug strip"

CURRENT_NUGETS_DEPEND="
	~dev-dotnet/dotnet-runtime-nugets-${RUNTIME_SLOT}
"
EXTRA_NUGETS_DEPEND="
	~dev-dotnet/dotnet-runtime-nugets-6.0.36
	~dev-dotnet/dotnet-runtime-nugets-7.0.20
	~dev-dotnet/dotnet-runtime-nugets-8.0.32
	~dev-dotnet/dotnet-runtime-nugets-9.0.21
	~dev-dotnet/dotnet-runtime-nugets-10.0.15
"
PDEPEND="
	${CURRENT_NUGETS_DEPEND}
	${EXTRA_NUGETS_DEPEND}
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

	if [[ "${MERGE_TYPE}" != binary ]] && has network-sandbox ${FEATURES} ; then
		einfo "src_prepare restores portable runtime packs from Azure Artifacts."
		einfo "That step needs network. Re-emerge with FEATURES=\"-network-sandbox\"."
	fi
}

src_unpack() {
	unpack "${P}.tar.gz"
	mv "${WORKDIR}/dotnet-${PV}" "${S}" || die
}

src_prepare() {
	default

	strip-flags
	filter-flags -Werror=lto-type-mismatch  # Not implemented by Clang, bug 946334
	filter-flags -Wlto-type-mismatch
	filter-lto

	# With shadow stacks enabled (e.g. `-march=native` on Zen 3+ or Tiger Lake+)
	# and Gentoo's default `-fcf-protection`, the bundled llvm-libunwind turns on
	# its CET support, whose helpers are defined in headers that the NativeAOT
	# runtime also includes, and linking `ilc` fails with "duplicate symbol:
	# __libunwind_cet_get_jump_target". strip-flags would drop this, so add it
	# afterwards.
	if use amd64 ; then
		append-flags -mno-shstk
	fi

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

	# NuGet writes UTC into the local-time fields of nupkg entries. West of UTC,
	# the SDK packages the build unpacks for later repos get mtimes in the
	# future, so projects importing them rebuild on every request and race on
	# their output assemblies (MSB3248 "being used by another process").
	export TZ="UTC"

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

	local boot_rid archive_dir="${S}/prereqs/packages/archive"
	if use amd64 ; then
		boot_rid="linux-x64"
	elif use arm64 ; then
		boot_rid="linux-arm64"
	else
		die "no bootstrap SDK for this architecture"
	fi

	mkdir -p "${archive_dir}" "${S}/.dotnet" || die
	tar -xzf "${DISTDIR}/dotnet-sdk-${BOOT_PV}-${boot_rid}.tar.gz" -C "${S}/.dotnet" || die
	cp "${DISTDIR}/Private.SourceBuilt.Artifacts.${BOOT_PV}.centos.10-x64.tar.gz" "${archive_dir}/" || die

	# Staging the tarball makes prep skip its download, and the portable-pack
	# rewrite only runs inside that download branch. Do it here so binary
	# removal unpacks runtime.${boot_rid} packages instead of centos.10-x64.
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

	local -a prep_args=(
		--no-sdk
		--no-prebuilts
		# The portable packs were already rewritten above.
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

	local verbosity="${DOTNET_VERBOSITY:-minimal}"

	local -a buildopts=(
		--source-repository "https://github.com/dotnet/dotnet"
		--source-version "${COMMIT}"

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
