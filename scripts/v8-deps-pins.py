#!/usr/bin/env python3
"""Regenerate the V8_DEPS pin list for dev-lang/v8 from upstream DEPS.

Usage:
    v8-deps-pins.py 15.4.64              # print the V8_DEPS array
    v8-deps-pins.py 15.4.64 --check-patches DIR

To revbump the ebuild, use scripts/v8-revbump.py instead of pasting by hand.

Only the V8 tarball itself is a distfile.  Everything below is fetched by
git-r3 at a pinned commit, because chromium.googlesource.com generates
+archive tarballs on the fly and they are not byte-reproducible, so they
can never carry a stable Manifest hash.
"""

import argparse
import base64
import pathlib
import subprocess
import sys
import tarfile
import tempfile
import urllib.request

GS = "https://chromium.googlesource.com"

# Dependencies the Gentoo build actually consumes, and why.  Anything not
# listed here is deliberately skipped: android/fuchsia/cros support, test
# corpora, and the prebuilt toolchains we replace with Gentoo's.
NEEDED = {
    "build": "chromium build/ system: toolchain, compiler configs, unbundle scripts",
    "buildtools": "GN helper configs referenced by build/",
    "tools/clang": "clang config plumbing referenced by build/config/clang",
    "third_party/abseil-cpp": "linked into libv8",
    "third_party/partition_alloc": "V8's allocator",
    "third_party/zlib": "bundled zlib; the unbundle shim needs Chromium's //base",
    "third_party/jinja2": "code generation templates",
    "third_party/markupsafe": "jinja2 dependency",
    "third_party/googletest/src": "//testing/gtest targets in the GN graph",
    "third_party/dragonbox/src": "float formatting",
    "third_party/fp16/src": "half-float support",
    "third_party/fast_float/src": "number parsing",
    "third_party/simdutf": "UTF conversion",
    "third_party/highway/src": "SIMD helpers",
    "third_party/re2/src": "regexp helpers in the GN graph",
    "third_party/fadec/src": "x86 disassembler",
    "third_party/disarm/src": "arm64 disassembler",
    "third_party/llvm-libc/src": "shared math headers used by src/base/ieee754.cc",
}

# Unconditional dependencies we knowingly do not fetch, as of 15.4.64.  Any
# unconditional dependency missing from both this and NEEDED is new upstream
# and gets reported, which is the signal worth looking at on a bump.
IGNORED = {
    "third_party/icu": "1.2GB of history for two .gn files; synthesized instead",
    "third_party/libc++/src": "use_custom_libcxx=false, we link libstdc++",
    "third_party/libc++abi/src": "use_custom_libcxx=false",
    "third_party/libunwind/src": "system unwinder",
    "third_party/perfetto": "v8_use_perfetto=false",
    "third_party/protobuf": "only reachable via perfetto and fuzztest",
    "third_party/fuzztest": "v8_enable_fuzztest=false",
    "third_party/fuzztest/src": "v8_enable_fuzztest=false",
    "third_party/rust": "enable_rust=false",
    "tools/rust": "enable_rust=false",
    "third_party/libpfm4": "perf profiling support, not enabled",
    "third_party/libpfm4/src": "perf profiling support, not enabled",
    "third_party/jsoncpp/source": "test tooling only",
    "third_party/google_benchmark_chrome": "checkout_google_benchmark=false",
    "third_party/google_benchmark_chrome/src": "checkout_google_benchmark=false",
    "third_party/clang-format/script": "developer tooling",
    "third_party/depot_tools": "we deliberately do not use gclient",
    "third_party/logdog": "bot infrastructure",
    "third_party/logdog/logdog": "bot infrastructure",
    "agents/shared": "bot infrastructure",
    "test/benchmarks/data": "test corpora; we only build d8",
    "test/mozilla/data": "test corpora",
    "test/test262/data": "test corpora",
    "tools/protoc_wrapper": "only needed with perfetto/protobuf",
    "tools/win": "Windows only",
}


# chromium.googlesource.com mirrors these two without a HEAD ref (their
# branches are refs/heads/upstream/*).  git-r3 probes HEAD to pick sha1 vs
# sha256 before it will create its store, so it dies with "Unrecognized
# hash:" no matter which ref we ask for.  The pins are commit SHAs, so the
# upstream GitHub repositories give identical content.
URL_OVERRIDES = {
    "third_party/fadec/src": "https://github.com/aengelke/fadec.git",
    "third_party/disarm/src": "https://github.com/aengelke/disarm.git",
}


def fetch_deps(version):
    url = f"{GS}/v8/v8/+/refs/tags/{version}/DEPS?format=TEXT"
    with urllib.request.urlopen(url) as f:
        return base64.b64decode(f.read()).decode()


def eval_deps(source):
    """Evaluate a gclient DEPS file well enough to read deps and vars."""
    ns = {}

    def Var(name):
        return str(ns["vars"][name])

    def Str(value):
        return str(value)

    ns["Var"] = Var
    ns["Str"] = Str
    exec(compile(source, "DEPS", "exec"), ns)
    return ns


def resolve_pins(version):
    """Return {resolved, missing, added, block} for a V8 tag."""
    deps = eval_deps(fetch_deps(version))["deps"]

    resolved = {}
    unconditional = set()
    for path, entry in deps.items():
        split = split_entry(entry)
        if split is None:
            continue
        url, revision, condition = split
        resolved[path] = (URL_OVERRIDES.get(path, url), revision)
        if not condition:
            unconditional.add(path)

    missing = [p for p in NEEDED if p not in resolved]
    added = sorted(unconditional - set(NEEDED) - set(IGNORED))
    return {
        "version": version,
        "resolved": resolved,
        "missing": missing,
        "added": added,
        "block": "" if missing else format_v8_deps(version, resolved),
    }


def format_v8_deps(version, resolved):
    width = max(len(p) for p in NEEDED)
    lines = [f"# Generated by scripts/v8-deps-pins.py {version}", "V8_DEPS=("]
    for path in NEEDED:
        url, revision = resolved[path]
        lines.append(f'\t"{path.ljust(width)} {url} {revision}"')
    lines.append(")")
    return "\n".join(lines) + "\n"


def check_remote_heads(resolved, paths=None):
    """Return paths whose remote has no usable HEAD.

    git-r3 cannot create its store for such a repository, so this is fatal
    long before anything is compiled.  Add an entry to URL_OVERRIDES.
    """
    broken = []
    for path in paths if paths is not None else NEEDED:
        url = resolved[path][0]
        result = subprocess.run(
            ["git", "ls-remote", url, "HEAD"],
            capture_output=True,
            text=True,
        )
        head = result.stdout.split()[0] if result.stdout.split() else ""
        if result.returncode != 0 or len(head) not in (40, 64):
            broken.append(path)
    return broken


def split_entry(entry):
    """Return (url, revision, condition) for a deps entry, or None if not git."""
    condition = ""
    if isinstance(entry, dict):
        if "packages" in entry or entry.get("dep_type") in ("cipd", "gcs"):
            return None
        condition = entry.get("condition", "")
        url = entry["url"]
    else:
        url = entry
    if "@" not in url:
        return None
    repo, _, revision = url.rpartition("@")
    return repo.rstrip(), revision, condition


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("version")
    ap.add_argument(
        "--check-patches",
        metavar="DIR",
        help="dry-run *.patch from DIR against the new chromium build/ pin",
    )
    args = ap.parse_args()

    pins = resolve_pins(args.version)
    if pins["missing"]:
        sys.exit(
            "These dependencies are gone from DEPS and the ebuild must be "
            "updated by hand:\n  " + "\n  ".join(pins["missing"])
        )

    sys.stdout.write(pins["block"])

    if pins["added"]:
        print(
            "\n# New unconditional dependencies upstream added; check whether "
            "the\n# build needs them (gn gen and ninja will say so):",
            file=sys.stderr,
        )
        for path in pins["added"]:
            print(f"#   {path}", file=sys.stderr)

    if args.check_patches:
        patch_dir = pathlib.Path(args.check_patches)
        patches = sorted(patch_dir.glob("*.patch"))
        if not patches:
            sys.exit(f"no patches found in {patch_dir}")
        ok, log = check_patches(patches, pins["resolved"]["build"][1])
        print(log, file=sys.stderr, end="" if log.endswith("\n") else "\n")
        if not ok:
            sys.exit("patches need refreshing")


def check_patches(patches, build_revision):
    """Dry-run build/ patches against the pinned chromium build/ tree.

    Returns (ok, log).  patches is an iterable of Paths.
    """
    patches = list(patches)
    if not patches:
        return False, "no patches to check\n"

    url = f"{GS}/chromium/src/build.git/+archive/{build_revision}.tar.gz"
    lines = [
        f"checking {len(patches)} patch(es) against build/ {build_revision[:12]}\n"
    ]

    with tempfile.TemporaryDirectory() as tmp:
        tmp = pathlib.Path(tmp)
        archive = tmp / "build.tar.gz"
        with urllib.request.urlopen(url) as f:
            archive.write_bytes(f.read())
        target = tmp / "build"
        target.mkdir()
        with tarfile.open(archive) as tar:
            tar.extractall(target, filter="data")

        failed = False
        for patch in patches:
            result = subprocess.run(
                ["patch", "-p1", "--dry-run", "--force", "-i", str(patch)],
                cwd=tmp,
                capture_output=True,
                text=True,
            )
            status = "ok" if result.returncode == 0 else "FAILED"
            lines.append(f"  {patch.name}: {status}\n")
            if result.returncode != 0:
                failed = True
                extra = (result.stdout or "") + (result.stderr or "")
                if extra:
                    lines.append(extra if extra.endswith("\n") else extra + "\n")
        return (not failed), "".join(lines)


if __name__ == "__main__":
    main()
