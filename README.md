# 有道词典 8.10.8.0 · 免安装便携包

为网易有道词典 **8.10.8.0** 提供免安装封装、启动脚本与关闭自动更新的辅助措施。
**非官方发行版，不提供会员权限，不保证旧版在线服务长期可用。**

## 普通用户：下载即可使用

1. 打开 [最新 Release](https://github.com/astmain/xp-youdao/releases/latest)。
2. 在 **Assets** 下载 **`YoudaoDict-8.10.8.0-Portable-Windows.zip`**。
3. **完整解压**到有写入权限的文件夹，例如 `D:\Apps\YoudaoDict`。不要直接在压缩包里运行。
4. 退出已经运行的其他有道词典，双击 **`start-youdao.cmd`**。

**Release ZIP 已包含完整运行文件，不需要 Git、Git LFS 或安装包。**
不要把 GitHub 自动生成的 `Source code (zip)` 当成免安装包使用。
启动脚本使用 Windows 自带的 PowerShell 5.1；当前封装面向 Windows 桌面环境，未验证 XP 或所有系统版本的兼容性。

如需桌面和开始菜单快捷方式，在解压目录执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-shortcuts.ps1
```

### “便携”的范围

这是**解压即用的免安装包，不是完全不留痕的绿色软件**：

- 程序仍使用 `%LOCALAPPDATA%\Yodao\DeskDict` 保存设置、缓存和用户数据。
- 启动脚本会设置 `AUTOUPDATE=0`，将 `updaters` 替换成只读占位文件，并调整 `HKCU\Software\Youdao\Dict\Install`。
- 如果已有相关开机自启动项或卸载记录，脚本会将其指向当前文件夹；不会主动为新用户新增开机启动项。
- 这些设置属于同一 Windows 用户账号下的共享状态，可能影响其他有道安装。不要同时运行多份副本。
- 不需要管理员权限。不要放到 `Program Files` 等需要管理员写权限的位置。

## 下载校验

Release 同时提供 `SHA256SUMS.txt`。下载后可检查 ZIP 的 SHA-256：

```powershell
Get-FileHash .\YoudaoDict-8.10.8.0-Portable-Windows.zip -Algorithm SHA256
```

结果应与 Release 附带的校验文件一致。包内也有逐文件的 `SHA256SUMS.txt` 和记录源代码提交的 `BUILD.txt`。

## 开发者：从仓库运行

```powershell
git lfs install
git clone https://github.com/astmain/xp-youdao.git
cd xp-youdao
git lfs pull
.\start-youdao.cmd
```

`8.10.8.0/libcef.dll` 使用 Git LFS，完整大小为 **143,979,576 字节**。
启动脚本会检查版本与运行文件是否完整，再应用防更新措施。

## 防更新方式与验证边界

1. 将配置文件中的 `AUTOUPDATE` 设为 `0`。
2. 如存在 `updaters` 目录，先改名保留，再创建同名只读普通文件，阻止升级器在该路径创建目录。
3. 将当前用户注册表里的安装路径指向本文件夹。

历史测试中曾发现用户配置重新变为 `AUTOUPDATE=1` 并再次下载新版；**无法仅凭现有记录确认究竟是哪个操作重置了设置**，因此不把“每 30 分钟必然重置”作为已证实的程序行为。
此前在一份从 GitHub 全新克隆的副本上，做过清空用户配置后的启动测试和 **32.5 分钟运行观察**，没有发现新升级文件，版本仍为 8.10.8.0。这不等于永久保证。

只修复防更新设置而不启动：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\protect-youdao.ps1
```

恢复更新前先退出词典，再删除占位文件并把配置改回 `AUTOUPDATE=1`；再次使用本项目启动脚本会重新关闭更新。
注意：不要运行版本目录里的 `YoudaoDictInstaller.exe`，它是程序附带的安装辅助工具，不是本项目的推荐启动入口。

## 维护与构建 Release

```powershell
# 确保 Git LFS 文件已拉取，并先提交受版本控制文件的改动
git lfs pull
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-release.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-release.ps1 -ZipPath .\dist\YoudaoDict-8.10.8.0-Portable-Windows.zip
```

构建脚本只选择受 Git 管理的运行文件、启动脚本和说明文档，不递归复制工作目录。
输出到 `dist/`：ZIP 和 ZIP 的 `SHA256SUMS.txt`。
同名 ZIP 已存在时会拒绝覆盖，可用 `-OutputDirectory` 指定新目录。
测试脚本校验包内所有运行文件的哈希、LFS 文件完整性，以及是否夹带日志或个人数据。

主要目录：

```text
YoudaoDict.exe               主程序（8.10.8.0）
8.10.8.0/                   词库、界面与运行组件
Stable/                     取词组件等
start-youdao.cmd             推荐启动入口
scripts/start-youdao.ps1     启动前检查与版本防护
scripts/protect-youdao.ps1   当前用户级防更新设置
scripts/install-shortcuts.ps1  可选快捷方式
scripts/build-release.ps1   构建 ZIP（仅仓库维护使用）
scripts/test-release.ps1    校验 ZIP（仅仓库维护使用）
```

本机快捷方式、日志、`*.new` 升级文件、`guid.dat`、`vendor.dat`、用户配置和缓存不纳入发布包。

## 第三方权利与安全提示

详见 [第三方软件说明](THIRD-PARTY-NOTICE.md)。有道程序及附带词库、字体、组件等归各自权利人所有，公开仓库不等于这些文件已开源或已核实再分发授权。
旧版固定使用也意味着不会自动获取新版本安全修复。若安全软件告警，请先核验来源和风险，**不要盲目关闭防护**。
