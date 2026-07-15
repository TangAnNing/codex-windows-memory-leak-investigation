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
