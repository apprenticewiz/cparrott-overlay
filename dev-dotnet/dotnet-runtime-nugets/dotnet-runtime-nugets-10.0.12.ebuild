# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DOTNET_PKG_COMPAT="$(ver_cut 1-2)"
NUGETS="
microsoft.aspnetcore.app.ref@${PV}
microsoft.aspnetcore.app.runtime.linux-arm@${PV}
microsoft.aspnetcore.app.runtime.linux-arm64@${PV}
microsoft.aspnetcore.app.runtime.linux-musl-arm@${PV}
microsoft.aspnetcore.app.runtime.linux-musl-arm64@${PV}
microsoft.aspnetcore.app.runtime.linux-musl-x64@${PV}
microsoft.aspnetcore.app.runtime.linux-x64@${PV}
microsoft.dotnet.ilcompiler@${PV}
microsoft.net.illink.tasks@${PV}
microsoft.net.sdk.webassembly.pack@${PV}
microsoft.netcore.app.host.linux-arm@${PV}
microsoft.netcore.app.host.linux-arm64@${PV}
microsoft.netcore.app.host.linux-musl-arm@${PV}
microsoft.netcore.app.host.linux-musl-arm64@${PV}
microsoft.netcore.app.host.linux-musl-x64@${PV}
microsoft.netcore.app.host.linux-x64@${PV}
microsoft.netcore.app.ref@${PV}
microsoft.netcore.app.runtime.linux-arm@${PV}
microsoft.netcore.app.runtime.linux-arm64@${PV}
microsoft.netcore.app.runtime.linux-musl-arm@${PV}
microsoft.netcore.app.runtime.linux-musl-arm64@${PV}
microsoft.netcore.app.runtime.linux-musl-x64@${PV}
microsoft.netcore.app.runtime.linux-x64@${PV}
runtime.linux-arm64.microsoft.dotnet.ilcompiler@${PV}
runtime.linux-musl-arm64.microsoft.dotnet.ilcompiler@${PV}
runtime.linux-musl-x64.microsoft.dotnet.ilcompiler@${PV}
runtime.linux-x64.microsoft.dotnet.ilcompiler@${PV}
"

# Published by Loongson, not nuget.org.
LOONG_NUGETS="
microsoft.aspnetcore.app.runtime.linux-loongarch64@${PV}
microsoft.aspnetcore.app.runtime.linux-musl-loongarch64@${PV}
microsoft.netcore.app.host.linux-loongarch64@${PV}
microsoft.netcore.app.host.linux-musl-loongarch64@${PV}
microsoft.netcore.app.runtime.linux-loongarch64@${PV}
microsoft.netcore.app.runtime.linux-musl-loongarch64@${PV}
runtime.linux-loongarch64.microsoft.dotnet.ilcompiler@${PV}
runtime.linux-musl-loongarch64.microsoft.dotnet.ilcompiler@${PV}
"

inherit dotnet-pkg-base

DESCRIPTION=".NET runtime nugets"
HOMEPAGE="https://dotnet.microsoft.com/
	https://www.loongnix.cn/zh/api/dotnet/"
SRC_URI="${NUGET_URIS}"
for _loong_nuget in ${LOONG_NUGETS} ; do
	_loong_id="${_loong_nuget%@*}"
	SRC_URI+=" https://lnuget.loongnix.cn/v3/package/${_loong_id}/${PV}/${_loong_id}.${PV}.nupkg"
done
unset _loong_nuget _loong_id
S="${WORKDIR}"

LICENSE="MIT"
SLOT="${PV}/${PV}"
KEYWORDS="~amd64 ~arm64 ~loong ~riscv"

src_unpack() {
	:
}

src_install() {
	local nuget
	for nuget in ${NUGETS} ${LOONG_NUGETS} ; do
		nuget_donuget "${DISTDIR}/${nuget/@/.}.nupkg"
	done
}
