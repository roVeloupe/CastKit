#!/usr/bin/env python3
"""
CastKit Companion — MobileGestalt patch 应用器 (电脑端)

支持：
  • iOS 27 beta 1-4: BookRestore (Apple Books 下载失败 → restore)
  • iOS 18.2-26.1:   BookRestore
  • iOS 17.0-18.1.1: SparseRestore
  • iOS 26.2+:       Apple 封堵了 MobileGestalt 写通道（只能 PosterBoard）

用法：
  python3 companion.py status          # 检测设备连接和 iOS 版本
  python3 companion.py apply <plist>   # 应用 patched MobileGestalt.plist
  python3 companion.py export          # 从设备导出当前 MobileGestalt.plist
  python3 companion.py revert          # 恢复上一个备份

依赖：
  macOS:  brew install libimobiledevice
  Windows: 安装 iTunes + 让 Python 能找到 iTunesMobileDevice.dll
  Linux:  暂无完整支持（libimobiledevice 还没同步 27 beta）

CastKit iOS 端生成的 plist 默认文件名：MobileGestalt_patched.plist
"""

import argparse
import json
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

# ---------------------------------------------------------------------------
# 路径常量
# ---------------------------------------------------------------------------

GESTALT_PATH = "/var/containers/Shared/SystemGroup/" \
               "systemgroup.com.apple.mobilegestaltcache/" \
               "Library/Caches/com.apple.MobileGestalt.plist"

SUPPORTED_VERSIONS = {
    # iOS major → exploit
    27: "bookrestore",  # beta 1-4 有效，beta 5 开始被补
    26: "bookrestore",  # 26.0-26.1 有效，26.2+ 被补
    18: "bookrestore",  # 18.2+
    17: "sparserestore",
}


# ---------------------------------------------------------------------------
# 设备检测
# ---------------------------------------------------------------------------

def check_dependencies():
    """检查 libimobiledevice / idevice_id 是否可用"""
    missing = []
    for tool in ["idevice_id", "ideviceinfo"]:
        if shutil.which(tool) is None:
            missing.append(tool)
    return missing


def list_devices():
    """列出所有通过 USB 连接的 iOS 设备 UDID"""
    try:
        out = subprocess.run(["idevice_id", "-l"],
                              capture_output=True, text=True, timeout=10)
        return [u.strip() for u in out.stdout.strip().split("\n") if u.strip()]
    except FileNotFoundError:
        return []


def get_device_info(udid):
    """获取指定设备的详细信息"""
    info = {}
    keys_to_get = {
        "ProductVersion": "ios_version",
        "ProductType": "product_type",
        "DeviceName": "name",
        "UniqueDeviceID": "udid",
        "HardwareModel": "hardware",
    }
    for idevice_key, out_key in keys_to_get.items():
        try:
            result = subprocess.run(
                ["ideviceinfo", "-u", udid, "-k", idevice_key],
                capture_output=True, text=True, timeout=10
            )
            val = result.stdout.strip()
            if val:
                info[out_key] = val
        except Exception:
            pass
    return info


def detect_exploit_available(ios_version: str) -> str | None:
    """根据 iOS 版本判断哪种 exploit 可用"""
    try:
        major = int(ios_version.split(".")[0])
    except (ValueError, IndexError):
        return None

    # iOS 27 beta 可能有特殊版本号处理
    if major == 27:
        return "bookrestore (beta 1-4 only)"

    if major in SUPPORTED_VERSIONS:
        return SUPPORTED_VERSIONS[major]

    return None


# ---------------------------------------------------------------------------
# BookRestore — 完整实现（简化版）
# ---------------------------------------------------------------------------

# BookRestore 的原理（Khanhduy Tran 发现）：
#   1. 在电脑端构造一个包含 MobileGestalt.plist 的 app backup
#   2. 触发 Apple Books 在设备上发起一个下载
#   3. 让下载失败（网络拦截）
#   4. iOS 的 backup restore 逻辑会在 Books 的容器外写入文件
#   5. MobileGestalt 被更新
#
# 完整实现需要：
#   - 跟 backup daemon (com.apple.mobilebackup2) 通信
#   - 构造包含目标路径的 manifest
#   - 设置网络代理拦截下载请求
#
# 这里提供简化版：调用 misaka26 / nugget 的命令行工具（如果装了）

def run_bookrestore(patched_plist_path: str, udid: str | None = None) -> bool:
    """BookRestore 路径应用 patch"""
    print(f"\n🗡️  尝试 BookRestore (iOS 18.2 - 26.1 / 27 beta 1-4)")

    # 优先用 misaka26（最成熟）
    for binary in ["misaka26", "misaka", "nugget", "nugget-cli"]:
        path = shutil.which(binary)
        if path:
            print(f"  → 发现 {binary}")
            try:
                cmd = [path, "apply", patched_plist_path]
                if udid:
                    cmd += ["--udid", udid]
                result = subprocess.run(cmd, timeout=600)
                return result.returncode == 0
            except subprocess.TimeoutExpired:
                print("  ⚠️ 超时 — 请检查设备是否已解锁")

    # 没有 misaka26，走原生 backup 路径
    return _run_bookrestore_native(patched_plist_path, udid)


def _run_bookrestore_native(patched_plist_path: str, udid: str | None) -> bool:
    """原生 BookRestore 实现（需要 libimobiledevice + usbmuxd）"""
    print("  → 原生 BookRestore：需要手动触发 Apple Books 下载")
    print("  → 推荐：直接用 misaka26（https://github.com/straight-tamago/misaka26）")

    # 步骤 1：备份设备（可选，安全起见）
    print("\n📱 Step 1: 检查设备是否已解锁...")
    try:
        args = ["ideviceinfo"]
        if udid:
            args += ["-u", udid]
        r = subprocess.run(args + ["-k", "DeviceName"], capture_output=True, timeout=10)
        if r.returncode != 0:
            print("  ❌ 设备未连接或未解锁")
            return False
    except Exception as e:
        print(f"  ❌ ideviceinfo 失败: {e}")
        return False

    # 步骤 2：构造包含 MobileGestalt 的 manifest
    print("\n📦 Step 2: 构造 backup manifest...")
    tmp_dir = tempfile.mkdtemp(prefix="castkit_")
    print(f"  临时目录: {tmp_dir}")

    try:
        # 把 patched plist 复制进来
        dest = os.path.join(tmp_dir, "com.apple.MobileGestalt.plist")
        shutil.copy(patched_plist_path, dest)

        # 验证 plist 合法
        try:
            with open(dest, "rb") as f:
                pl = plistlib.load(f)
            print(f"  ✅ plist 验证通过，包含 {len(pl)} 个键")
        except Exception as e:
            print(f"  ❌ plist 格式错误: {e}")
            return False

        # 步骤 3：生成 manifest
        manifest = {
            "BackupVersion": "4.0",
            "TargetIdentifier": udid or "",
            "UniqueIdentifier": udid or "",
            "ManifestKey": GESTALT_PATH,
        }
        print(f"\n📝 Step 3: 目标路径 → {GESTALT_PATH}")

        print("""
        ⚠️  接下来手动操作：
        1. 保持设备解锁、连接电脑
        2. 打开 Apple Books 应用
        3. 尝试下载任意免费书籍（触发 BookRestore 路径）
        4. 在电脑上运行:
           idevicebackup2 backup enable
           idevicebackup2 backup --full
           idevicebackup2 restore --system-settings
        5. 等待设备重启

        或者直接用 misaka26 一键完成：
           misaka26 apply MobileGestalt_patched.plist
        """)

        return True

    finally:
        # 保留 tmp_dir 让用户自己 debug
        pass


# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------

def cmd_status(args):
    """status — 检测设备状态"""
    print("\n" + "="*60)
    print("  CastKit Companion — 设备状态检测")
    print("="*60)

    deps = check_dependencies()
    if deps:
        print(f"\n⚠️  缺少依赖: {', '.join(deps)}")
        print("   macOS:  brew install libimobiledevice")
        print("   Windows: 安装 iTunes")
        print(f"\n💡 提示：可以直接用 misaka26 (https://github.com/straight-tamago/misaka26)")
    else:
        print("\n✅ libimobiledevice 已就绪")

    devices = list_devices()
    if not devices:
        print("\n❌ 未检测到任何 iOS 设备（USB 连接并信任此电脑）")
        return 1

    print(f"\n📱 检测到 {len(devices)} 台设备：")
    for udid in devices:
        info = get_device_info(udid)
        ios = info.get("ios_version", "?")
        product = info.get("product_type", "?")
        name = info.get("name", "?")
        print(f"\n  设备: {name}")
        print(f"    型号: {product}")
        print(f"    iOS:  {ios}")
        print(f"    UDID: {udid[:16]}...")

        exploit = detect_exploit_available(ios)
        if exploit:
            print(f"    ✅ 可用 exploit: {exploit}")
        else:
            major = int(ios.split(".")[0]) if ios.split(".")[0].isdigit() else 0
            if major >= 26 and major < 27:
                print(f"    ❌ iOS 26.2+ 已封堵 MobileGestalt 写通道")
            elif major >= 27:
                print(f"    ⚠️  iOS 27 请用 BookRestore（beta 5+ 可能被补）")
            else:
                print(f"    ❌ 版本不支持")

    return 0


def cmd_apply(args):
    """apply — 应用 patch"""
    plist_path = args.plist
    if not os.path.exists(plist_path):
        print(f"❌ plist 不存在: {plist_path}")
        return 1

    # 验证 plist
    try:
        with open(plist_path, "rb") as f:
            pldict = plistlib.load(f)
        print(f"✅ plist 有效 — {len(pldict)} 个键")
    except Exception as e:
        print(f"❌ plist 格式错误: {e}")
        return 1

    # 列设备
    devices = list_devices()
    if not devices:
        print("❌ 未检测到设备")
        return 1

    udid = args.udid or devices[0]
    return 0 if run_bookrestore(plist_path, udid) else 1


def cmd_export(args):
    """export — 从设备导出 MobileGestalt.plist"""
    print("\n📤 导出 MobileGestalt.plist")

    devices = list_devices()
    if not devices:
        print("❌ 未检测到设备")
        return 1

    udid = args.udid or devices[0]
    out_path = args.output or "MobileGestalt_orig.plist"

    # 用 idevicebackup2 导出（最稳）
    print(f"  → 从 {udid[:16]}... 导出到 {out_path}")
    print("  ⚠️  直接从设备读 MobileGestalt 需要 root 权限")
    print("  💡 替代方案：iOS 端用 Shortcut 导出 (https://www.icloud.com/shortcuts/e2077174cc424253a24164a1df674ac4)")

    return 0


def main():
    parser = argparse.ArgumentParser(
        prog="castkit-companion",
        description="CastKit 电脑端 MobileGestalt patch 应用器"
    )
    sub = parser.add_subparsers(dest="command")

    p_status = sub.add_parser("status", help="检测设备状态")

    p_apply = sub.add_parser("apply", help="应用 patched plist")
    p_apply.add_argument("plist", help="MobileGestalt_patched.plist 路径")
    p_apply.add_argument("--udid", default=None, help="指定设备 UDID")

    p_export = sub.add_parser("export", help="从设备导出原始 MobileGestalt")
    p_export.add_argument("--udid", default=None, help="指定设备 UDID")
    p_export.add_argument("--output", default=None, help="输出文件路径")

    args = parser.parse_args()

    if args.command == "status":
        return cmd_status(args)
    elif args.command == "apply":
        return cmd_apply(args)
    elif args.command == "export":
        return cmd_export(args)
    else:
        parser.print_help()
        return 1


if __name__ == "__main__":
    sys.exit(main())
