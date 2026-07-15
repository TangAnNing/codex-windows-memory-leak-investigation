# Codex Windows Memory Exhaustion Investigation

[中文说明](README.md)

## Summary

On my Windows 11 laptop, keeping Codex Desktop open for approximately
one hour caused physical memory usage to increase to 95-99%.

Windows Explorer, window switching, and mouse input eventually became
slow or completely unresponsive.

Without Codex running, physical memory usage remained stable at
approximately 35%.

## System Environment

- Device: Lenovo Legion R7000P APH8
- Model: 82Y9
- Physical memory: 16 GB
- Integrated GPU: AMD Radeon 780M
- Discrete GPU: NVIDIA GeForce RTX 4060 Laptop GPU
- Operating system: Windows 11
- Application: Codex Desktop for Windows

## Symptoms

The following symptoms appeared after Codex Desktop remained open for
approximately one hour:

- Physical memory usage reached 95-99%
- Available physical memory dropped to approximately 100-600 MB
- Windows Explorer became unresponsive
- Window switching and mouse input became extremely slow
- CPU, disk, network, and GPU utilization were not saturated
- No individual process appeared to account for all of the missing memory

When Codex was not running, the system remained stable.

## Initial Hypotheses

The investigation initially considered the following possible causes:

1. A custom MCP server
2. A Skill running continuously in the background
3. A Codex plugin process
4. An Electron renderer private-memory leak
5. Corrupted application cache or restored session state
6. Background project directory scanning
7. Antivirus interaction
8. GPU shared-memory or display-driver leakage

## Eliminated Causes

### Custom MCP Servers

The `[mcp_servers]` section in the Codex configuration was empty.
No manually configured MCP server was running.

### Skills

Skills are instruction and resource files. They do not independently
execute or allocate large amounts of memory unless they are invoked.

### Plugins and Application Cache

Most plugins were disabled, the detailed command-rendering option was
removed, and the packaged application data was reset.

The issue still reproduced.

### Codex Backend Process

The `codex.exe` backend process remained at approximately 25 MB during
the captured failure period.

This process could not explain several gigabytes of additional committed
memory.

### Codex Desktop Shell

The Codex desktop shell runs under the process name `ChatGPT.exe`.

During the captured failure period, the combined private memory of the
ChatGPT processes remained at approximately 0.88-0.94 GB.

It did not increase together with the system commit charge.

### Unrelated Browser Processes

Several processes named `browser.exe` were investigated.

Their parent processes showed that they belonged to WeGame and
`df_helper_main.exe`, not to the Codex Browser plugin.

## Monitoring Method

A PowerShell monitoring script recorded system and process memory
approximately every 10 seconds.

The following values were collected:

- Available physical memory
- System committed bytes
- System commit limit
- Paged pool memory
- Nonpaged pool memory
- Total process-private memory
- Total process working set
- Process count
- Private memory and handle counts grouped by process name
- Detailed process snapshots when available memory fell below the
  configured threshold

## Captured Data

| Metric | Start | End | Change |
|---|---:|---:|---:|
| System committed memory | 12.84 GB | 21.19 GB | +8.34 GB |
| Available physical memory | 5.4 GB | 131 MB | -5.26 GB |
| Total process-private memory | 5.80 GB | 5.81 GB | +10.6 MB |
| Nonpaged pool | 848 MB | 1.46 GB | +613.6 MB |
| Paged pool | 579 MB | 814 MB | +235.6 MB |
| Unattributed commit growth | - | - | Approximately +7.48 GB |

The system commit charge increased by approximately 8.34 GB, while total
ordinary process-private memory increased by only 10.6 MB.

Approximately 7.48 GB of additional committed memory was not explained
by ordinary process-private memory or the measured paged and nonpaged
pools.

## Important Process Observations

| Process | Observed behavior |
|---|---|
| `ChatGPT.exe` | Remained at approximately 0.88-0.94 GB |
| `codex.exe` | Remained at approximately 25 MB |
| `dwm.exe` | Private memory remained around 160 MB while its working set was trimmed |
| Razer/CefSharp processes | Started late in the failure period and added only several hundred MB |
| `RadeonSoftware.exe` | Private memory remained stable |
| NVIDIA container processes | Private memory remained stable |

This behavior did not match an ordinary JavaScript or Electron
process-private heap leak.

## Probable Cause

The captured data indicates that most of the additional committed memory
was allocated outside ordinary process-private memory.

The most likely categories include:

- Graphics shared commit
- DirectX or DXGI mappings
- GPU shared-memory allocations
- Display-driver-managed allocations
- Kernel allocations associated with graphics resources
- Hybrid-GPU resource-management problems

The affected machine uses hybrid graphics:

- AMD Radeon 780M integrated GPU
- NVIDIA GeForce RTX 4060 Laptop GPU

Codex Desktop is based on Electron and creates GPU-accelerated rendering
resources, shared textures, and DirectX resources.

At the time of the investigation, the installed AMD integrated graphics
driver was substantially older than the NVIDIA driver.

## Driver Versions

### Before the Update

AMD Radeon 780M:

```text
Driver version: 31.0.14005.22001
Driver date: 2023-11-08
```

NVIDIA GeForce RTX 4060 Laptop GPU:

```text
Driver version: 32.0.16.1074
Driver date: 2026-07-02
```

### After the Update

The AMD Radeon 780M driver was updated to:

```text
AMD Software: Adrenalin Edition 26.6.4 WHQL
Driver version: 32.0.31021.5001
Driver date: 2026-06-28
```

## Resolution

The following remediation steps were performed:

1. Downloaded AMD Software: Adrenalin Edition 26.6.4 WHQL from the
   official AMD support page
2. Installed the updated AMD Radeon 780M graphics driver
3. Restarted Windows
4. Confirmed that the new driver version was active
5. Reopened Codex Desktop
6. Continued observing physical memory and system commit usage

After restarting Windows, physical memory remained stable and the issue
did not reproduce during the observation period.

The initial post-update state showed approximately:

```text
Physical memory available: 7.99 GB
Physical memory used: 7.2 GB
Physical memory usage: 47.4%
System commit: 9.45 GB / 29.89 GB
Page file usage: 247 MB
```

## Monitoring Script

Run the monitoring script from PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\monitor-memory-leak.ps1"
```

Keep the PowerShell window open while monitoring.

Press `Ctrl+C` to stop monitoring.

The script writes data into a `memory-monitor` directory containing:

- `system.csv`
- `process-groups.csv`
- `process-pids.csv`

## Repository Structure

```text
codex-windows-memory-leak-investigation/
├── README.md
├── README_EN.md
├── LICENSE
├── SECURITY.md
├── scripts/
│   └── monitor-memory-leak.ps1
├── evidence/
│   ├── task-manager-processes.png
│   ├── task-manager-memory.png
│   └── memory-summary.csv
└── docs/
    └── investigation-summary.md
```

## Evidence

- [Task Manager process view](evidence/task-manager-processes.png)
- [Task Manager memory view](evidence/task-manager-memory.png)
- [Monitoring summary](evidence/memory-summary.csv)
- [Detailed investigation summary](docs/investigation-summary.md)

## Suggested Troubleshooting Order

If another user experiences similar symptoms, the following order may
help:

1. Check system committed memory, not only the Task Manager process list
2. Compare system commit growth with total process-private memory growth
3. Check paged and nonpaged pool usage
4. Verify whether `ChatGPT.exe` or `codex.exe` actually grows
5. Update the integrated GPU driver
6. Update the chipset driver
7. Restart Windows
8. Test Codex with the discrete GPU selected
9. Disable GPU overlays and recording tools
10. If the issue continues, test with Hardware-Accelerated GPU Scheduling
    disabled

## Scope and Limitations

This repository documents one specific machine and does not prove that
all Codex memory problems are caused by AMD drivers.

The evidence strongly indicates a graphics shared-commit or driver-layer
issue on this system, but the investigation did not capture:

- Historical GPU Process Memory counters
- PoolMon pool tags
- ETW GPU allocation traces
- A kernel memory dump

Therefore, the investigation cannot identify one exact AMD, NVIDIA,
DirectX, or Windows driver module with absolute certainty.

The driver update stopped the issue from reproducing on this machine,
but this result should be treated as a documented case rather than a
universal fix.

## Privacy Notice

The monitoring script may record:

- Process names
- Process IDs
- Executable paths
- Timestamps
- Handle counts
- Memory usage

Review and anonymize monitoring output before publishing it.

Do not publish:

- API keys or tokens
- Codex configuration files containing private endpoints
- Raw conversation files
- Authentication databases
- Personal project paths
- Computer serial numbers
- Unreviewed complete logs

## License

This project is licensed under the MIT License.
