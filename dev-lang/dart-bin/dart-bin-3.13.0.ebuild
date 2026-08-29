# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Official prebuilt Dart SDK from Google"
HOMEPAGE="https://dart.dev/"
SRC_URI="https://storage.googleapis.com/dart-archive/channels/stable/release/${PV}/sdk/dartsdk-linux-x64-release.zip
	-> dartsdk-${PV}-linux-x64.zip"
S="${WORKDIR}/dart-sdk"

LICENSE="BSD"
SLOT="0"
KEYWORDS="-* ~amd64"
REQUIRED_USE="elibc_glibc"

BDEPEND="app-arch/unzip"
RESTRICT="strip"

QA_PREBUILT="*"

src_install() {
	# The SDK expects its own layout: bin/dart resolves snapshots and the
	# bundled runtime relative to itself, so install it whole and symlink.
	dodir /opt/dart-sdk
	cp -a . "${ED}/opt/dart-sdk/" || die

	dosym -r /opt/dart-sdk/bin/dart /usr/bin/dart
	dosym -r /opt/dart-sdk/bin/dartaotruntime /usr/bin/dartaotruntime

	local f
	for f in README LICENSE; do
		if [[ -f ${ED}/opt/dart-sdk/${f} ]]; then
			dodoc "${ED}/opt/dart-sdk/${f}"
			rm "${ED}/opt/dart-sdk/${f}" || die
		fi
	done
}
