# Codex Windows Memory Exhaustion Investigation

[English version](README_EN.md)

## 问题说明

在我的 Windows 11 笔记本上，Codex Desktop 打开约一小时后，
物理内存会逐渐升至 95%-99%。

接近故障时会出现：

- Windows 资源管理器无响应
- 鼠标和窗口切换严重卡顿
- 可用物理内存只剩约 100-600 MB
- 不打开 Codex 时，内存长期稳定在约 35%

## 设备环境

- 设备：Lenovo Legion R7000P APH8
- 物理内存：16 GB
- 核显：AMD Radeon 780M
- 独显：NVIDIA RTX 4060 Laptop GPU
- 操作系统：Windows 11
- Codex Desktop：Windows 商店版本

## 排除过程

排查过以下方向：

- 手动配置的 MCP：配置为空
- Skill：不会在未调用时自行运行
- Codex 插件：禁用后仍然复现
- Codex 缓存：重置后仍然复现
- codex.exe 后端：内存长期约 25 MB
- ChatGPT.exe 桌面壳：长期约 0.9 GB，没有数 GB 级增长

## 监控方法

监控脚本每 10 秒记录：

- 系统提交内存
- 可用物理内存
- 分页池和非分页池
- 全部进程私有内存
- 各进程组内存和句柄数

运行方法：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\monitor-memory-leak.ps1"

## 解决方案

在这台电脑上，最终有效的处理方法是更新 AMD Radeon 780M
核显驱动。

### 更新前

```text
设备：AMD Radeon 780M
驱动版本：31.0.14005.22001
驱动日期：2023-11-08
```

### 更新后

```text
AMD Software: Adrenalin Edition 26.6.4 WHQL
驱动版本：32.0.31021.5001
驱动日期：2026-06-28
```

### 操作步骤

1. 从电脑厂商或 AMD 官方网站下载适用于 Radeon 780M 的驱动。
2. 本案例安装的是 `AMD Software: Adrenalin Edition 26.6.4 WHQL`。
3. 安装时选择推荐安装或完整安装。
4. 暂时不要选择 Factory Reset，除非普通安装失败。
5. 安装完成后重新启动 Windows。
6. 确认设备管理器中的 AMD Radeon 780M 驱动版本已经更新。
7. 重新打开 Codex，观察至少 60 至 90 分钟。
8. 检查物理内存、系统提交量和非分页池是否保持稳定。

### 如果更新驱动后仍然复现

按照下面的顺序继续测试：

1. 更新 AMD 芯片组驱动。
2. 在 Windows 显示卡设置中将 Codex 的 `ChatGPT.exe`
   指定为使用 RTX 4060。
3. 完全退出并重新启动 Codex。
4. 关闭 AMD、NVIDIA 和 Razer 的游戏覆盖层及录制功能。
5. 关闭“硬件加速 GPU 计划”，重启后再次测试。
6. 使用本仓库的监控脚本记录系统提交量、进程私有内存、
   分页池和非分页池。

### 本机验证结果

驱动更新并重启后：

```text
可用物理内存：约 7.99 GB
物理内存使用率：约 47.4%
系统提交量：9.45 GB / 29.89 GB
分页文件使用量：247 MB
```

继续运行 Codex 后，物理内存基本保持稳定，原先持续上涨到
95%-99% 的问题暂未再次复现。

> 注意：这是本机的有效解决方案，不代表所有 Codex 内存问题都由
> AMD 驱动引起。其他电脑仍应根据监控数据判断实际原因。
