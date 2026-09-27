# Anne-Neri 药役专用服 —— Windows Server 2022 部署说明

下面这些都是ai写的，后续有空重写

本目录原本是**纯 Linux** 的 L4D2 服务端配置包（`*.so` 二进制 + `srcds_run` 启动方式）。
现已**在原目录内补齐 Windows 版本二进制**，改造后同一份文件**同时支持 Linux 与 Windows Server 2022**：

- Linux 文件（`*.so`、`linux64/`、`x64/`）全部原样保留，Linux 部署方式不变；
- 新增 Windows 文件（`*.dll`），Metamod / SourceMod 会按平台自动选择对应二进制；
- 所有 `.vdf` 插件清单本来就是**不带扩展名**的写法（如 `addons/l4dtoolz/l4dtoolz_mm`），
  在 Windows 上自动解析为 `.dll`、在 Linux 上解析为 `.so`，**无需修改**。

---

## 1. 版本对照（与 Linux 端严格对齐）

| 组件 | Linux 端（原包） | Windows 端（本次补齐） |
|---|---|---|
| Metamod:Source | 1.11.0-dev+1155 | **1.11.0-git1155**（同版本） |
| SourceMod | 1.11.0.6964 | **1.11.0-git6964**（同版本） |
| l4dtoolz | `l4dtoolz_mm.so` | `l4dtoolz_mm.dll`（Accelerator74 官方 2.2.0） |
| Tickrate Enabler | `tickrate_enabler.so` | `tickrate_enabler.dll`（accelerator74 build 42db945） |
| Stripper:Source | core 16 (`stripper.16.l4d2.so`) | core 16 (`stripper.16.l4d2.dll`) |
| 插件 | `plugins/*.smx` | **同一批 `.smx`，无需重编**（smx 跨平台） |

> SourceMod 插件（`.smx`）是平台无关的字节码，Windows / Linux 共用同一份，**不要**为 Windows 重新编译。

---

## 2. 部署步骤

### 2.1 安装 L4D2 专用服务端（SteamCMD）

```bat
:: 首次安装（约 12 GB），222860 = Left 4 Dead 2 Dedicated Server
steamcmd +force_install_dir C:\L4D2Srv +login anonymous +app_update 222860 validate +quit
```

### 2.2 拷贝本包

把本目录（`Anne-Neri(2024.10.18)`）内的**全部内容**拷贝到服务端的 `left4dead2` 目录：

```
C:\L4D2Srv\
├─ srcds.exe
└─ left4dead2\            <-- 本包内容整体放这里
   ├─ addons\
   ├─ cfg\
   ├─ scripts\
   ├─ start_server.bat
   └─ ...
```

### 2.3 放行防火墙端口（管理员 PowerShell）

```powershell
netsh advfirewall firewall add rule name="L4D2 Game UDP"   dir=in action=allow protocol=UDP localport=27015
netsh advfirewall firewall add rule name="L4D2 Game TCP"   dir=in action=allow protocol=TCP localport=27015
netsh advfirewall firewall add rule name="L4D2 SourceTV"   dir=in action=allow protocol=UDP localport=27020
```

建议同时给服务端目录加 Defender 排除项（显著降低卡顿）：

```powershell
Add-MpPreference -ExclusionPath C:\L4D2Srv
```

### 2.4 启动

双击或命令行运行 `left4dead2\start_server.bat`。

脚本会：
1. 以 `-tickrate 100` 启动 `srcds.exe`（tickrate_enabler 必需参数）；
2. 通过 `+exec server.cfg` 加载原服务器配置，再叠加 `cfg\windows_override.cfg`；
3. **进程退出后 10 秒自动重启**（替代 Linux 端的 `srcds_run` 看护循环）。

常用参数都在脚本顶部，直接改即可：

```bat
set "PORT=27015"
set "TICKRATE=100"
set "STARTMAP=c1m1_hotel"
set "GSLT="            :: 公网服务器填写游戏服务器登录令牌，内网留空
```

### 2.5 开机自启（可选，推荐 NSSM）

```bat
nssm install L4D2Anne "C:\L4D2Srv\left4dead2\start_server.bat"
nssm set  L4D2Anne AppDirectory "C:\L4D2Srv\left4dead2"
nssm start L4D2Anne
```

### 2.6 运行库

服务端自带大部分依赖 DLL（`tier0.dll`、`vstdlib.dll`、`steam_api.dll` 等随安装包一起）。
若启动时报缺少 `MSVCP140.dll` / `VCRUNTIME140.dll`，安装一次
**Microsoft Visual C++ 2015-2022 Redistributable (x86)** 即可（注意是 **x86** 版）。

---

## 3. 新增/变更文件清单

### 3.1 新增 Windows 二进制（33 个）

```
addons\metamod\bin\server.dll
addons\metamod\bin\metamod.2.l4d2.dll

addons\sourcemod\bin\sourcemod_mm.dll
addons\sourcemod\bin\sourcemod.2.l4d2.dll
addons\sourcemod\bin\sourcemod.logic.dll
addons\sourcemod\bin\sourcepawn.jit.x86.dll
addons\sourcemod\scripting\spcomp.exe
addons\sourcemod\scripting\compile.exe

addons\sourcemod\extensions\bintools.ext.dll
addons\sourcemod\extensions\clientprefs.ext.dll
addons\sourcemod\extensions\dbi.mysql.ext.dll
addons\sourcemod\extensions\dbi.pgsql.ext.dll
addons\sourcemod\extensions\dbi.sqlite.ext.dll
addons\sourcemod\extensions\dhooks.ext.dll
addons\sourcemod\extensions\geoip.ext.dll
addons\sourcemod\extensions\regex.ext.dll
addons\sourcemod\extensions\sdkhooks.ext.2.l4d2.dll
addons\sourcemod\extensions\sdktools.ext.2.l4d2.dll
addons\sourcemod\extensions\topmenus.ext.dll
addons\sourcemod\extensions\updater.ext.dll
addons\sourcemod\extensions\webternet.ext.dll
addons\sourcemod\extensions\game.cstrike.ext.2.csgo.dll
addons\sourcemod\extensions\game.cstrike.ext.2.css.dll
addons\sourcemod\extensions\game.tf2.ext.2.tf2.dll
addons\sourcemod\extensions\SteamWorks.ext.dll
addons\sourcemod\extensions\builtinvotes.ext.2.l4d2.dll
addons\sourcemod\extensions\collisionhook.ext.dll
addons\sourcemod\extensions\sourcescramble.ext.dll
(addons\sourcemod\extensions\custom_fakelag.ext.2.l4d2.dll  ← 原包已自带)

addons\l4dtoolz\l4dtoolz_mm.dll
addons\tickrate_enabler.dll
addons\stripper\bin\stripper_mm.dll
addons\stripper\bin\stripper.core.dll
addons\stripper\bin\stripper.16.l4d2.dll
```

### 3.2 新增脚本 / 配置

| 文件 | 作用 |
|---|---|
| `start_server.bat` | Windows 启动脚本 + 崩溃自动重启循环 |
| `cfg\windows_override.cfg` | 仅 Windows 生效的 cvar 覆盖层（默认全注释，不影响任何行为） |

### 3.3 未改动

`cfg\**`、`plugins\**`、`translations\**`、`gamedata\**`、`scripts\**`、`*.vpk`
以及所有 Linux `*.so` **均保持原样**。

---

## 4. 组件来源（可追溯）

| 组件 | 来源 |
|---|---|
| Metamod:Source 1.11.0-git1155 | `https://mms.alliedmods.net/mmsdrop/1.11/` 官方包 |
| SourceMod 1.11.0-git6964 | `https://sm.alliedmods.net/smdrop/1.11/` 官方包（含 dhooks / updater 等官方扩展） |
| l4dtoolz_mm.dll | Accelerator74/l4dtoolz **2.2.0** Windows 构建（与 L4D2-Competitive-Rework 同款） |
| tickrate_enabler.dll | accelerator74/Tickrate-Enabler `build` 42db945（2025-10-30） |
| stripper 三件套 | SirPlease/L4D2-Competitive-Rework v1.0.0 windows 包（Stripper core 16，与 Linux 端版本号一致） |
| SteamWorks.ext.dll | 镜像仓库 `azimuth87/L4D2_Survival_Localhost`（上游 KyleSanderson/SteamWorks **只发布 Linux/macOS 包**，Windows 版需取自社区镜像） |
| builtinvotes / collisionhook / sourcescramble `.dll` | SirPlease/L4D2-Competitive-Rework v1.0.0 windows 包 |
| spcomp.exe / compile.exe | SourceMod 1.11 官方 Windows 包（方便在服务器上重编插件） |

---

## 5. 插件 → 扩展 依赖对照（Windows 端已全部满足）

| 扩展 | 依赖它的插件（节选） | Windows 文件 |
|---|---|---|
| DHooks | `left4dhooks.smx` | `dhooks.ext.dll` ✅ |
| Updater | `left4dhooks.smx`、`extend\updater.smx`、`extend\lilac.smx` | `updater.ext.dll` ✅ |
| SteamWorks | `familyshare_manager.smx`、`optional\gamedescription.smx`、`optional\jointeam.smx` | `SteamWorks.ext.dll` ✅ |
| BuiltinVotes | `match_vote.smx`、`optional\l4d_boss_vote.smx`、`optional\match_vote2.smx`、`optional\readyup.smx`、`optional\slots_vote.smx`、`optional\votespec.smx`、`optional\player_fakelag.smx` | `builtinvotes.ext.2.l4d2.dll` ✅ |
| CollisionHook | `optional\l4d2_spit_spread_patch.smx`、`optional\l4d2_jockeyed_ladder_fix.smx` | `collisionhook.ext.dll` ✅ |
| SourceScramble | `sourcescramble_manager.smx`、`code_patcher.smx` | `sourcescramble.ext.dll` ✅ |
| CustomFakelag | `optional\player_fakelag.smx` | `custom_fakelag.ext.2.l4d2.dll` ✅（原包自带） |
| Left4DHooks | 大量 `optional\*` / `extend\*` 插件 | 由 `left4dhooks.smx` 本体提供 ✅ |

> 校验方式：`sm exts list` 中上述扩展应全部显示为 `Running`。

---

## 6. Windows 与 Linux 的差异说明

1. **自动重启（`plugins\linux_auto_restart.smx`）**
   - 插件信息：名称 `L4D auto restart`，作者 Harry Potter，
     描述 "make server restart (Force crash) when the last player disconnects from the server"。
   - 作用：**最后一个真人玩家离开后，主动让服务端强制崩溃退出**（控制台 `crash`），
     由外部看护循环把服务器重启回干净状态（清空缓存/内存碎片、复位地图与状态）。
   - 它和 `optional\server*.smx` 都会调用 `Accelerator` 扩展的 `UnloadAccelerator` / `GetAcceleratorId`
     （**原包并未提供该扩展**），但两者都使用 `MarkNativeAsOptional` 把相关原生标记为可选，
     所以**不会因此加载失败**，只是"卸载 Accelerator"这条分支不生效，其余功能照常。
   - Windows 下：`start_server.bat` 已提供等价的重启循环（进程退出即重启），机制上可继续使用该插件。
   - **如果不需要"空服后自动崩溃重启"**，两步即可关闭（Linux / Windows 同时生效）：
     1) 把 `addons\sourcemod\plugins\linux_auto_restart.smx` 移到 `addons\sourcemod\plugins\disabled\`；
     2) 注释掉下面 5 处 `sm plugins load linux_auto_restart.smx`：
        - `cfg\cfgogl\realism\shared_plugins.cfg`
        - `cfg\cfgogl\Mutation4\shared_plugins.cfg`
        - `cfg\cfgogl\coop-10t5s\shared_plugins.cfg`
        - `cfg\cfgogl\coop-10t5s-hard\shared_plugins.cfg`
        - `cfg\cfgogl\AnneHappy-happy\shared_plugins.cfg`
     （`plugins\extend\linux_auto_restart.smx` 是未参与加载的副本，可一并删除。）

2. **socket / geoipcity 扩展**
   - 原包里的 `socket.ext.so`、`geoipcity.ext.so` 在 1.11 官方包中已不再提供，
     经全量解析所有 `.smx` 依赖后确认：**没有任何在用插件真正调用它们的原生函数**
     （`confoglcompmod.smx` 只是包含了 `socket.inc`，其扩展声明为非必需 `required = 0`）。
   - 因此 Windows 端未提供这两个 `.dll`，属正常。

3. **`l4d_scs_zoey`（survivor_chat_select）**
   - 插件注释标明该 cvar 取值与平台相关：`0: Rochelle (windows)` / `1: Zoey (linux)`，
     原配置为 Linux 值 `1`。
   - 若 Windows 下选人菜单里的 Zoey 道具显示异常，在 `cfg\windows_override.cfg` 中启用
     `l4d_scs_zoey 0` 即可（注意该插件会在地图切换时重新执行自己的 cfg，参见文件内注释）。

4. **`addons\metamod_x64.vdf`**
   - 仍指向 `addons/metamod/bin/linux64/server`。L4D2 在 Windows 上没有 x64 服务端，
     该文件在 Windows 下不生效，保持原样以免影响 Linux 端。

5. **`gamedata\l4d2addresses.txt`（code_patcher 用）**
   - 该文件**本来就同时包含 `windows` / `linux` 两套签名与偏移**（`"Signatures"` 段 + 各 Addresses 的
     `windows`/`linux` 分支），Windows 端无需修改。✅

---

## 7. 启动后自检清单

在服务器控制台（或 RCON）依次执行：

```
meta version          -> 1.11.0-dev+1155 (或相近)，说明 Metamod 正常
meta list             -> SourceMod / l4dtoolz / stripper / tickrate_enabler 全部 RUN
sm version            -> SourceMod 1.11.0.6964
sm exts list          -> DHooks / SteamWorks / BuiltinVotes / CollisionHook / SourceScramble / CustomFakelag 全部 Running
sm plugins list       -> 无 "Failed to load" 报错（若保留 linux_auto_restart，见 6.1 说明）
stats                 -> tickrate 显示 100（需配合 -tickrate 100 启动参数）
```

日志位置：

```
left4dead2\console.log                              (-condebug 输出)
left4dead2\addons\sourcemod\logs\*.log              (SourceMod 日志)
```

---

## 8. 常见问题

| 现象 | 原因 / 处理 |
|---|---|
| `stats` 显示 30 tick | 确认启动参数含 `-tickrate 100`，且 `addons\tickrate_enabler.dll` 存在。L4D2 每次游戏更新后 Tickrate Enabler 通常需要更新，可到 accelerator74/Tickrate-Enabler 取最新 `build`。 |
| `meta list` 没有 l4dtoolz | 检查 `addons\l4dtoolz\l4dtoolz_mm.dll`。未加载时 `server.cfg` 里的 `sv_maxplayers 8` 不生效（会退回 4 人）。 |
| 插件报 `Native "SteamWorks_xxx" was not found` | `SteamWorks.ext.dll` 缺失或位数不对（必须是 x86），见第 5 节。 |
| 插件报 `Unable to load plugin ... (required extension)` | 按第 5 节补齐对应 `.dll`，或把该插件移入 `plugins\disabled\`。 |
| 服务器启动即闪退 | 用 `start_server.bat` 查看控制台输出；常见原因是 `srcds.exe` 路径不对、端口被占用、`-game left4dead2` 参数缺失。 |
| 公网搜不到服务器 | 检查 GSLT（`sv_setsteamaccount`）、端口映射（UDP 27015）、`sv_lan 0`。 |

---

## 9. 回滚

本次改造是**纯增量**：删除新增的 `*.dll` / `start_server.bat` / `cfg\windows_override.cfg` 即可恢复为
原始 Linux 专用包，原有文件未被覆盖或删除。

---

## 附录 A：包内几个容易混淆的插件

> 这些插件**与平台无关**（`.smx` 跨平台），此表只为排查/维护时对照用途。
> 信息来自对 `.smx` 解压后的插件信息块（名称 / 作者 / 描述 / 命令 / cvar）。

| 插件 | 名称与来源 | 作用 |
|---|---|---|
| `optional\server.smx`<br>`optional\server_ast.smx`<br>`optional\server_eazy.smx`<br>`optional\server_ht_party.smx` | **AnneServer Server Function**（作者 Caibiii，<https://github.com/Caibiii/AnneServer>，编译于 2022.04.24） | 同一套"服务器功能"插件按模式各存一份，各 cfg 只加载其中一个。提供的命令：`sm_ip` 查询并显示服务器公网 IP（地址由 `sm_cfgip_url` 决定，默认 `http://111.67.204.59/aliyun/serverip.php`）、`sm_restartmap` 重载当前地图、`sm_restart` 踢出所有玩家并重启服务器（崩溃法，配合看护循环）、`sm_away` 挂机、`sm_join` / `sm_jg` 加入/换边、`sm_s`；并会按地图执行 `cfg/sourcemod/map_cvars/<地图名>.cfg` |
| `optional\server_si.smx` | **AnneServer** v7.54.3（作者 PaimonQwQ，<http://github.com/PaimonQwQ/L4D2-Plugins>） | 另一位作者的同类功能插件，命令更多：`sm_it`、`sm_c`、`sm_cs`、`sm_playtank`、`sm_taketank`、`sm_changeclass`、`sm_ammo`、`sm_spec`、`sm_team`、`sm_team3`、`sm_inf`、`sm_restartmap`、`sm_restart` 等（主要面向特感/换职业/托管玩法） |
| `optional\server_name.smx`<br>`optional\server_name_coop.smx` | **Server Namer** 1.0.1.0（作者 saku_ra） | 从 `addons\sourcemod\configs\hostname\hostname.txt` 读取服务器名并定时刷新 `hostname`（对应根目录 `readme.txt` 提到的"服务器名字文件路径"）。两个文件分别给对抗 / 战役使用 |
| `plugins\linux_auto_restart.smx` | **L4D auto restart**（作者 Harry Potter） | 空服后强制崩溃重启，详见 6.1 |
| `plugins\sourcescramble_manager.smx` | 需 `SourceScramble` 扩展 | 运行期加载/管理源码补丁（配合 `gamedata\*.txt`） |
| `plugins\code_patcher.smx` | 需 `SourceScramble` 扩展 | 按 `gamedata\l4d2addresses.txt` 里的签名/偏移给服务端打内存补丁（该 gamedata 本来就含 `windows` / `linux` 两套） |
