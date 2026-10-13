#!/usr/bin/env python3
"""检测 ACL 权限在软件包配置与签名 Profile 中是否同时具备且一一对应。

对齐 AGC 上架检测项「ACL权限声明一致性」：
  - module.json5 中声明、且属于受限开放权限的权限，必须出现在 Profile 的 allowed-acls 中；
  - Profile 的 allowed-acls 不允许出现软件包未声明的权限。

默认读取工程 build-profile.json5 中所有 signingConfigs 的 Profile 逐一检测。

用法:
    python3 tools/check-acl-consistency.py
    python3 tools/check-acl-consistency.py --profile path/to/xx.p7b [--profile ...]
    python3 tools/check-acl-consistency.py --module entry/src/main/module.json5

受限权限清单来源：华为官方《受限开放权限》文档（references/harmonyos-guides/restricted-permissions.md，2026-09-24 更新，共 97 项）。
文档更新后可用以下命令重新生成并替换 ACL_PERMISSIONS：
    curl -s https://raw.githubusercontent.com/liasica/harmonyos-skills/master/harmonyos/references/harmonyos-guides/restricted-permissions.md \
      | grep -o '^## ohos\\.permission\\.[A-Za-z0-9_.\\\\]*' | sed 's/^## //; s/\\\\//g' | sort -u

退出码：0 全部一致；1 存在不一致；2 参数或文件错误。
"""
import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

ACL_PERMISSIONS = frozenset({
    'ohos.permission.ACCESS_DDK_DRIVERS',
    'ohos.permission.ACCESS_DDK_HID',
    'ohos.permission.ACCESS_DDK_SCSI_PERIPHERAL',
    'ohos.permission.ACCESS_DDK_USB',
    'ohos.permission.ACCESS_DDK_USB_SERIAL',
    'ohos.permission.ACCESS_DIGITAL_IDENTITY',
    'ohos.permission.ACCESS_DISK_PHY_INFO',
    'ohos.permission.ACCESS_DLP_SERVICE',
    'ohos.permission.ACCESS_FIDO2_ONLINEAUTH',
    'ohos.permission.ACCESS_GAME_BUDDY_SERVICE',
    'ohos.permission.ACCESS_NET_TRACE_INFO',
    'ohos.permission.ACCESS_SE_KEY',
    'ohos.permission.ACCESS_USER_FULL_DISK',
    'ohos.permission.ACCESS_VIRTUAL_SCREEN',
    'ohos.permission.ALLOW_ACCESSORY_ACCESS',
    'ohos.permission.ALLOW_EXTERNAL_NATIVE_CODE',
    'ohos.permission.ALLOW_USE_BM',
    'ohos.permission.AUTO_RESTORE_MAIN_WINDOW',
    'ohos.permission.CAPTURE_PLAYBACK_DOWNLINK',
    'ohos.permission.CHECK_CALL_LOG',
    'ohos.permission.CONTROL_DEVICE',
    'ohos.permission.CRYPTO_EXTENSION_REGISTER',
    'ohos.permission.CUSTOMIZE_SAVE_BUTTON',
    'ohos.permission.CUSTOM_SANDBOX',
    'ohos.permission.CUSTOM_SCREEN_RECORDING',
    'ohos.permission.DETECT_DEVICE',
    'ohos.permission.DLP_GET_HIDE_STATUS',
    'ohos.permission.FILE_ACCESS_PERSIST',
    'ohos.permission.FLOAT_VIEW',
    'ohos.permission.GET_ABILITY_INFO',
    'ohos.permission.GET_CALL_TRANSFER_INFO',
    'ohos.permission.GET_ETHERNET_LOCAL_MAC',
    'ohos.permission.GET_IP_MAC_INFO',
    'ohos.permission.GET_NETWORK_STATS',
    'ohos.permission.GET_WIFI_LOCAL_MAC',
    'ohos.permission.GET_WIFI_PEERS_MAC',
    'ohos.permission.HOOK_KEY_EVENT',
    'ohos.permission.INPUT_DEVICE_CONFIGURATOR',
    'ohos.permission.INPUT_MONITORING',
    'ohos.permission.INTERCEPT_INPUT_EVENT',
    'ohos.permission.KEEP_BACKGROUND_RUNNING_SPECIAL_SCENARIO',
    'ohos.permission.KEEP_BACKGROUND_RUNNING_SYSTEM',
    'ohos.permission.KNOCK_COLLABORATION',
    'ohos.permission.LINKTURBO',
    'ohos.permission.MANAGE_APN_SETTING',
    'ohos.permission.MANAGE_BLUETOOTH_ADVERTISER_NAME',
    'ohos.permission.MANAGE_CALL_FOR_DEVICES',
    'ohos.permission.MANAGE_MEDIA_RESOURCES_FOR_PUBLIC',
    'ohos.permission.MANAGE_PASTEBOARD_APP_SHARE_OPTION',
    'ohos.permission.MANAGE_RECENT_SNAPSHOT',
    'ohos.permission.MANAGE_SANDBOX_BUNDLE',
    'ohos.permission.MANAGE_SCREEN_TIME_GUARD',
    'ohos.permission.MANAGE_SKILL',
    'ohos.permission.MANAGE_UDMF_APP_SHARE_OPTION',
    'ohos.permission.PERSISTENT_BLUETOOTH_PEERS_MAC',
    'ohos.permission.PERSONAL_MANAGE_RESTRICTIONS',
    'ohos.permission.PRELOAD_FILE',
    'ohos.permission.PRINTER_DRIVER',
    'ohos.permission.READ_AUDIO',
    'ohos.permission.READ_CONTACTS',
    'ohos.permission.READ_IMAGEVIDEO',
    'ohos.permission.READ_LOCAL_DEVICE_NAME',
    'ohos.permission.READ_PASTEBOARD',
    'ohos.permission.READ_WHOLE_CALENDAR',
    'ohos.permission.READ_WRITE_DESKTOP_DIRECTORY',
    'ohos.permission.READ_WRITE_USB_DEV',
    'ohos.permission.READ_WRITE_USER_FILE',
    'ohos.permission.REGISTER_OBJECTEDITOR_EXTENSION',
    'ohos.permission.SET_PAC_URL',
    'ohos.permission.SET_SYSTEMSHARE_APPLAUNCHTRUSTLIST',
    'ohos.permission.SET_TELEPHONY_ESIM_STATE_OPEN',
    'ohos.permission.SET_WINDOW_ALPHA',
    'ohos.permission.SET_WINDOW_TOUCH_AREAS',
    'ohos.permission.SHORT_TERM_WRITE_IMAGEVIDEO',
    'ohos.permission.START_PROVISIONING_MESSAGE',
    'ohos.permission.SUBSCRIBE_NOTIFICATION',
    'ohos.permission.SYSTEM_FLOAT_WINDOW',
    'ohos.permission.USE_FLOAT_BALL',
    'ohos.permission.USE_FRAUD_APP_PICKER',
    'ohos.permission.USE_FRAUD_CALL_LOG_PICKER',
    'ohos.permission.USE_FRAUD_MESSAGES_PICKER',
    'ohos.permission.WEB_NATIVE_MESSAGING',
    'ohos.permission.WRITE_AUDIO',
    'ohos.permission.WRITE_CONTACTS',
    'ohos.permission.WRITE_IMAGEVIDEO',
    'ohos.permission.WRITE_WHOLE_CALENDAR',
    'ohos.permission.atomicService.MANAGE_AGING',
    'ohos.permission.atomicService.MANAGE_STORAGE',
    'ohos.permission.kernel.ALLOW_EXECUTABLE_FORT_MEMORY',
    'ohos.permission.kernel.ALLOW_USE_JITFORT_INTERFACE',
    'ohos.permission.kernel.ALLOW_WRITABLE_CODE_MEMORY',
    'ohos.permission.kernel.AS_LDK_DRIVER',
    'ohos.permission.kernel.DISABLE_CODE_MEMORY_PROTECTION',
    'ohos.permission.kernel.DISABLE_GOTPLT_RO_PROTECTION',
    'ohos.permission.kernel.LOAD_INDEPENDENT_LIBRARY',
    'ohos.permission.kernel.SUPPORT_LOCAL_PLUGIN',
    'ohos.permission.kernel.SUPPORT_PLUGIN',
})


def parse_json5(text: str):
    """宽松解析 JSON5：去注释、去尾逗号，字符串内不做处理。"""
    out = []
    i = 0
    n = len(text)
    in_str = False
    quote = ''
    while i < n:
        ch = text[i]
        if in_str:
            out.append(ch)
            if ch == '\\' and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            if ch == quote:
                in_str = False
            i += 1
            continue
        if ch in '"\'':
            in_str = True
            quote = ch
            out.append(ch)
            i += 1
            continue
        if ch == '/' and i + 1 < n and text[i + 1] == '/':
            j = text.find('\n', i)
            i = n if j < 0 else j
            continue
        if ch == '/' and i + 1 < n and text[i + 1] == '*':
            j = text.find('*/', i + 2)
            i = n if j < 0 else j + 2
            continue
        if ch == ',':
            j = i + 1
            while j < n and text[j] in ' \t\r\n':
                j += 1
            if j < n and text[j] in '}]':
                i += 1
                continue
        out.append(ch)
        i += 1
    return json.loads(''.join(out))


def read_p7b(path: Path):
    """从 .p7b（CMS 容器）中提取 Profile 明文 JSON。"""
    data = path.read_bytes()
    start = data.find(b'{"version-name"')
    if start < 0:
        raise ValueError(f'未在 {path} 中找到 Profile 内容')
    in_str = False
    escaped = False
    depth = 0
    end = -1
    for i in range(start, len(data)):
        ch = data[i:i + 1]
        if in_str:
            if escaped:
                escaped = False
            elif ch == b'\\':
                escaped = True
            elif ch == b'"':
                in_str = False
            continue
        if ch == b'"':
            in_str = True
        elif ch == b'{':
            depth += 1
        elif ch == b'}':
            depth -= 1
            if depth == 0:
                end = i + 1
                break
    if end < 0:
        raise ValueError(f'{path} 中 Profile JSON 不完整')
    return json.loads(data[start:end].decode('utf-8'))


def package_permissions(module_path: Path):
    module = parse_json5(module_path.read_text(encoding='utf-8'))
    perms = []
    for item in module.get('module', {}).get('requestPermissions', []) or []:
        name = item.get('name', '')
        if name:
            perms.append(name)
    return perms


def signing_configs(build_profile_path: Path):
    data = parse_json5(build_profile_path.read_text(encoding='utf-8'))
    configs = []
    for cfg in data.get('app', {}).get('signingConfigs', []) or []:
        profile = (cfg.get('material') or {}).get('profile', '')
        if not profile:
            continue
        path = Path(profile)
        if not path.is_absolute():
            path = (REPO_ROOT / path).resolve()
        configs.append((cfg.get('name', '?'), path))
    return configs


def check_consistency(module_path: Path, name: str, profile_path: Path) -> bool:
    declared = package_permissions(module_path)
    profile = read_p7b(profile_path)
    profile_acls = (profile.get('acls') or {}).get('allowed-acls', []) or []
    required = sorted(p for p in declared if p in ACL_PERMISSIONS)
    missing = sorted(set(required) - set(profile_acls))
    extra = sorted(set(profile_acls) - set(declared))

    bundle_name = (profile.get('bundle-info') or {}).get('bundle-name', '?')
    print(f'[{name}] {profile_path}')
    print(f'  Profile 类型: {profile.get("type", "?")} · 包名: {bundle_name}')
    print(f'  软件包 ACL 权限({len(required)}): {", ".join(required) or "无"}')
    print(f'  Profile allowed-acls({len(profile_acls)}): {", ".join(profile_acls) or "无"}')
    if missing:
        print(f'  ✗ Profile 缺少: {", ".join(missing)}')
    if extra:
        print(f'  ✗ Profile 多出（软件包未声明）: {", ".join(extra)}')
    if not missing and not extra:
        print('  ✓ 一致')
    print()
    return not missing and not extra


def main() -> int:
    parser = argparse.ArgumentParser(description='检测 ACL 权限在软件包与签名 Profile 中的一致性')
    parser.add_argument('--module', default=str(REPO_ROOT / 'entry/src/main/module.json5'),
                        help='模块 module.json5 路径（默认 entry/src/main/module.json5）')
    parser.add_argument('--build-profile', default=str(REPO_ROOT / 'build-profile.json5'),
                        help='工程 build-profile.json5 路径')
    parser.add_argument('--profile', action='append', default=[],
                        help='指定 Profile(.p7b)，可多次；缺省时检测 build-profile.json5 中所有 signingConfigs')
    args = parser.parse_args()

    module_path = Path(args.module)
    if not module_path.is_absolute():
        module_path = (REPO_ROOT / module_path).resolve()
    if not module_path.exists():
        print(f'找不到模块配置: {module_path}', file=sys.stderr)
        return 2

    if args.profile:
        targets = []
        for raw in args.profile:
            path = Path(raw)
            targets.append((path.stem, path if path.is_absolute() else (REPO_ROOT / path).resolve()))
    else:
        targets = signing_configs(Path(args.build_profile))
    if not targets:
        print('没有可检测的 Profile', file=sys.stderr)
        return 2

    print(f'模块配置: {module_path}\n')
    ok = True
    for name, profile in targets:
        if not profile.exists():
            print(f'[{name}] ✗ Profile 不存在: {profile}\n')
            ok = False
            continue
        ok = check_consistency(module_path, name, profile) and ok
    print('检测通过 ✓' if ok else '检测不通过 ✗')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
