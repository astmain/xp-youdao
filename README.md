# 有道词典 8.10.8.0（版本锁定版）

把网易有道词典固定在 **8.10.8.0**，阻止它自动升级到 11.x。

换电脑后重新克隆本仓库，双击 `start-youdao.cmd` 就能直接使用，不需要装安装包、不需要管理员权限。

## 快速开始（新电脑）

```powershell
git lfs install
git clone <本仓库地址> xp-youdao
cd xp-youdao
.\start-youdao.cmd
```

也可以直接双击 `start-youdao.cmd`。启动脚本会先重新应用版本锁定、清理残留升级包，再拉起词典。

仓库放在哪个目录都行，路径含中文或空格也没问题。

想让它出现在桌面/开始菜单，再执行一次：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-shortcuts.ps1
```

## 为什么要锁定版本

程序启动后会在后台拉起升级器 `0YoudaoDictUpt.exe`，从 `cidian.youdao.com/apps/update5/dictupdate.xml` 拉取版本信息，把新版下载成 `YoudaoDict.exe.new`，下次启动时替换掉自己。

锁定方式做了三道，从弱到强：

| # | 手段 | 作用 |
|---|------|------|
| 1 | `config.ini` 里 `AUTOUPDATE=0` | 关闭程序自带的自动更新开关 |
| 2 | 把 `%LOCALAPPDATA%\Yodao\DeskDict\updaters` 换成同名普通文件 | 升级器无法创建下载目录，这是决定性的一道锁 |
| 3 | 注册表 `HKCU\Software\Youdao\Dict\Install` 指向仓库目录 | 程序按仓库位置找自己的组件 |

实测：只做第 1 道锁时，程序运行约 30 分钟会自己把 `AUTOUPDATE` 改回 1 并开始下载。加上第 2 道锁后，多轮冷启动加长时间运行都没有再出现 `.new` 文件或升级进程。

顺带还会把开机自启动项、卸载入口、开始菜单快捷方式都指回本仓库，避免它们停留在 `%LOCALAPPDATA%\Youdao\Dict\Application` 这个会被自动更新删掉的旧目录。

## 目录结构

```
xp-youdao/
├─ YoudaoDict.exe          主程序（8.10.8.0）
├─ YodaoDict.exe           启动器
├─ InstallHelper.exe       安装辅助
├─ uninst.exe              卸载程序
├─ 8.10.8.0/               运行时资源（600 个文件，libcef.dll 走 LFS）
├─ Stable/                 插件与取词组件
├─ start-youdao.cmd        一键启动（推荐）
├─ scripts/
│   ├─ start-youdao.ps1    启动逻辑
│   ├─ protect-youdao.ps1  版本锁定（幂等，可单独运行）
│   └─ install-shortcuts.ps1  创建桌面/开始菜单快捷方式
├─ .gitattributes          二进制不做换行转换 + LFS 规则
└─ .gitignore              排除日志、升级包、用户数据
```

### 刻意不提交的内容

| 内容 | 原因 |
|------|------|
| `debug.log`、`logs/` | 每次启动都写，单个文件可达数百 MB |
| `*.new`、`11.*` | 自动更新下载的新版安装包，提交了就前功尽弃 |
| `config.ini`、`cookies.dat`、`user_pic/` | 本机私有设置，换机器不该覆盖对方 |
| `guid.dat`、`vendor.dat` | 设备标识，程序会自动生成 |

## 常用操作

### 只重新锁定，不启动

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\protect-youdao.ps1
```

可重复执行，无副作用。程序内出现更新提示时跑一次即可。

### 确认当前没被升级

```powershell
(Get-Item .\YoudaoDict.exe).VersionInfo.FileVersion
Get-ChildItem . -Filter *.new
Select-String "$env:LOCALAPPDATA\Yodao\DeskDict\config.ini" -Pattern AUTOUPDATE
```

正常结果：`8.10.8.0`、没有 `.new` 文件、`AUTOUPDATE=0`。

### 彻底恢复自动更新（不推荐）

```powershell
Remove-Item "$env:LOCALAPPDATA\Yodao\DeskDict\updaters" -Force
```

删掉占位文件后，把 `config.ini` 的 `AUTOUPDATE` 改回 `1`。

## 换电脑时的注意事项

1. **先装 Git LFS**，否则 `libcef.dll`（137 MB）拉不下来。克隆后确认大小约 143,979,576 字节；若只有一百多字节，说明拿到的是指针，执行 `git lfs pull`。

2. **别把仓库放进需要管理员权限的目录**（如 `C:\Program Files`），程序需以普通用户身份读写自己的目录。

3. **桌面快捷方式不会自动跟过来**，直接用 `start-youdao.cmd`；需要快捷方式可右键发送到桌面。

4. **杀毒软件可能拦截**：程序会写 `HKCU\Software\Youdao\Dict`，属正常行为，允许即可。

5. **不要运行**目录里的 `YoudaoDictInstaller.exe`，那是 11.x 的安装器，会把整个目录替换掉。

## 校验清单

```powershell
(Get-Item .\YoudaoDict.exe).VersionInfo.FileVersion                      # 期望 8.10.8.0
Get-ChildItem . -Filter *.new                                            # 期望空
(Get-Item "$env:LOCALAPPDATA\Yodao\DeskDict\updaters").PSIsContainer     # 期望 False
(Get-ItemProperty HKCU:\Software\Youdao\Dict).Install                    # 期望本仓库路径
```

