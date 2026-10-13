#!/usr/bin/env python3
"""将 signing/local.json5 中的签名配置注入 build-profile.json5。

build-profile.json5 中保留占位标记：

    "signingConfigs": /*SIGNING_CONFIGS*/ [],

本脚本用 signing/local.json5 的内容替换该标记。
signing/local.json5 不入库（见 .gitignore），clone 后需自行创建。
"""

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
PROFILE = ROOT / "build-profile.json5"
LOCAL = ROOT / "signing" / "local.json5"
MARKER = "/*SIGNING_CONFIGS*/ []"


def main() -> int:
    if not PROFILE.exists():
        print(f"error: {PROFILE} not found", file=sys.stderr)
        return 1
    if not LOCAL.exists():
        print(
            f"error: {LOCAL} not found; create it from the signing template",
            file=sys.stderr,
        )
        return 1

    signing = LOCAL.read_text(encoding="utf-8").strip()
    profile = PROFILE.read_text(encoding="utf-8")

    if MARKER not in profile:
        print(
            f"error: marker {MARKER!r} not found in {PROFILE.name}; "
            "it may already be injected — restore the placeholder first",
            file=sys.stderr,
        )
        return 1

    PROFILE.write_text(profile.replace(MARKER, signing, 1), encoding="utf-8")
    print(f"injected signing configs from {LOCAL} into {PROFILE.name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
