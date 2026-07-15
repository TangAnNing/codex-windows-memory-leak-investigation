# Codex Windows Memory Exhaustion Investigation Summary

## 1. Incident Overview

On the affected Windows 11 laptop, keeping Codex Desktop open for
approximately one hour caused physical memory usage to gradually increase
to 95-99%.

The issue could reproduce even when Codex was open but no active work was
being performed.

Without Codex running, physical memory usage remained stable at
approximately 35%.

## 2. User-Visible Symptoms

The following symptoms appeared as memory pressure increased:

- Windows Explorer became unresponsive
- Window switching became extremely slow
- Mouse input became delayed or unresponsive
- Task Manager became difficult to open or use
- Available physical memory dropped to approximately 100-600 MB
- CPU utilization remained relatively low
- Disk, network, and GPU utilization were not saturated
- No individual process appeared to consume all of the missing memory

A Task Manager screenshot captured the following state:

```text
Physical memory usage: 14.6 GB / 15.2 GB
Physical memory percentage: 96%
Available physical memory: 593 MB
Committed memory: 21.5 GB / 31.2 GB
Paged pool: 1.1 GB
Nonpaged pool: 1.6 GB
```

## 3. System Environment

The affected system had the following configuration:

```text
Manufacturer: Lenovo
Model: Legion R7000P APH8
Model number: 82Y9
Operating system: Windows 11
Physical memory: 16 GB
Integrated GPU: AMD Radeon 780M
Discrete GPU: NVIDIA GeForce RTX 4060 Laptop GPU
Application: Codex Desktop for Windows
```

## 4. Initial Hypotheses

The investigation initially considered the following possible causes:

1. A manually configured MCP server
2. A Skill continuously running in the background
3. A Codex plugin process
4. An Electron renderer private-memory leak
5. Corrupted Codex application cache
6. Restored conversation state
7. Background project directory scanning
8. Antivirus interaction
9. A WebView or browser subprocess
10. GPU shared-memory or display-driver leakage
11. A Windows paged or nonpaged pool leak
12. A hybrid-GPU resource-management issue

## 5. MCP Investigation

The Codex configuration contained an empty MCP section:

```toml
[mcp_servers]
```

No manually configured MCP server was present.

This made a custom MCP server an unlikely direct cause.

## 6. Skill Investigation

Skills are local instruction and resource files.

They do not independently execute, create processes, or allocate large
amounts of memory unless they are explicitly invoked by a task.

No evidence showed that a Skill process was continuously running in the
background.

## 7. Plugin and Cache Investigation

The following actions were attempted:

- Disabled most enabled Codex plugins
- Removed the detailed command-rendering option
- Reset the packaged Codex application data
- Cleared relevant application cache directories
- Restarted Codex
- Tested with reduced plugin functionality

The issue still reproduced.

This indicated that plugin configuration and cache corruption were not
the primary cause.

## 8. Process Identification

The Codex desktop application uses several processes.

The main desktop shell runs under:

```text
ChatGPT.exe
```

The Codex backend runs under:

```text
codex.exe
```

Additional helper processes may include:

```text
codex-code-mode-host.exe
node_repl.exe
```

Several processes named `browser.exe` were also investigated.

Their parent process relationships showed that they belonged to WeGame
and `df_helper_main.exe`, not to the Codex Browser plugin.

## 9. Monitoring Method

A PowerShell monitoring script was created to record system and process
memory approximately every 10 seconds.

The script recorded:

- Available physical memory
- System committed bytes
- System commit limit
- Paged pool memory
- Nonpaged pool memory
- Total process-private memory
- Total process working set
- Total process count
- Private memory grouped by process name
- Working set grouped by process name
- Handle count grouped by process name
- Detailed process snapshots near the low-memory threshold

The monitoring script is available at:

```text
scripts/monitor-memory-leak.ps1
```

It can be started with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\monitor-memory-leak.ps1"
```

Press `Ctrl+C` to stop monitoring.

## 10. Captured System Data

The monitoring session captured the system while memory was approaching
exhaustion.

| Metric | Start | End | Change |
|---|---:|---:|---:|
| System committed memory | 12.84 GB | 21.19 GB | +8.34 GB |
| Available physical memory | 5.4 GB | 131 MB | -5.26 GB |
| Total process-private memory | 5.80 GB | 5.81 GB | +10.6 MB |
| Nonpaged pool | 848 MB | 1.46 GB | +613.6 MB |
| Paged pool | 579 MB | 814 MB | +235.6 MB |
| Unattributed commit growth | - | - | Approximately +7.48 GB |

The most important observation was the difference between system commit
growth and process-private memory growth.

System committed memory increased by approximately:

```text
8.34 GB
```

Total ordinary process-private memory increased by only:

```text
10.6 MB
```

Approximately 7.48 GB of additional committed memory was not explained
by ordinary process-private memory or the measured paged and nonpaged
pools.

## 11. Codex Process Behavior

### ChatGPT.exe

The combined private memory of the Codex desktop shell processes remained
at approximately:

```text
0.88-0.94 GB
```

It did not increase together with the system commit charge.

### codex.exe

The backend process remained at approximately:

```text
25 MB
```

It could not explain several gigabytes of additional committed memory.

### Desktop Window Manager

`dwm.exe` private memory remained around 160 MB.

Its working set was repeatedly reduced as Windows attempted to recover
physical memory under pressure.

### Razer and CefSharp Processes

Razer Central, Razer Cortex, and several CefSharp subprocesses appeared
late in the failure period.

They added several hundred megabytes of process memory but did not explain
the earlier multi-gigabyte system commit growth.

### Graphics Control Processes

`RadeonSoftware.exe` and NVIDIA container process private memory remained
relatively stable.

## 12. Interpretation

An ordinary Electron or JavaScript heap leak would normally cause the
private memory of `ChatGPT.exe` or one of its renderer processes to
increase together with system commit.

That pattern was not observed.

Instead:

- System commit increased by several gigabytes
- Ordinary process-private memory remained almost unchanged
- Nonpaged pool memory increased
- Available physical memory approached zero
- Process working sets were aggressively trimmed by Windows
- Explorer and the desktop became unresponsive

This behavior is more consistent with memory allocated outside ordinary
process-private heaps.

Possible categories include:

- Graphics shared commit
- DirectX or DXGI mappings
- GPU shared-memory allocations
- Display-driver-managed allocations
- Kernel allocations associated with graphics resources
- Hybrid-GPU resource-management problems

## 13. Graphics Environment

The affected laptop uses hybrid graphics:

```text
AMD Radeon 780M integrated GPU
NVIDIA GeForce RTX 4060 Laptop GPU
```

Codex Desktop uses Electron.

Electron applications may create:

- GPU processes
- Hardware-accelerated rendering contexts
- DirectX resources
- Shared textures
- Desktop composition surfaces
- GPU shared-memory mappings

The AMD integrated GPU driver installed before remediation was
substantially older than the NVIDIA driver.

## 14. Driver Versions Before Remediation

AMD Radeon 780M:

```text
Driver version: 31.0.14005.22001
Driver date: 2023-11-08
Status: OK
```

NVIDIA GeForce RTX 4060 Laptop GPU:

```text
Driver version: 32.0.16.1074
Driver date: 2026-07-02
Status: OK
```

Although the AMD device status was reported as normal, the driver version
was substantially older.

## 15. Remediation

The AMD Radeon 780M driver was updated using the official AMD driver
package:

```text
AMD Software: Adrenalin Edition 26.6.4 WHQL
Release date: 2026-06-29
```

After installation, Windows reported:

```text
Device: AMD Radeon 780M
Driver version: 32.0.31021.5001
Driver date: 2026-06-28
Status: OK
```

The computer was restarted after installation.

## 16. Post-Update State

After restarting Windows, the initial system state was approximately:

```text
Total physical memory: 15.19 GB
Free physical memory: 7.99 GB
Used physical memory: 7.2 GB
Physical memory usage: 47.4%
System commit: 9.45 GB / 29.89 GB
Page file usage: 247 MB
```

Codex was reopened and observed again.

Physical memory remained substantially more stable than during the
original failure condition.

The previous continuous rise toward 95-99% did not reproduce during the
observation period.

## 17. Probable Causal Chain

The evidence supports the following probable sequence:

1. Codex Desktop starts its Electron interface.
2. Electron creates GPU-accelerated rendering and DirectX resources.
3. These resources pass through the AMD integrated GPU, NVIDIA discrete
   GPU, and Windows Desktop Window Manager hybrid-graphics path.
4. Shared graphics allocations or driver-managed mappings are not released
   correctly.
5. System committed memory increases without an equivalent increase in
   ordinary process-private memory.
6. Nonpaged pool memory also increases.
7. Available physical memory approaches zero.
8. Windows aggressively trims process working sets and starts paging.
9. Windows Explorer and desktop input become unresponsive.

## 18. Conclusion

The captured evidence does not support the following as the direct holder
of the missing memory:

- GPT model weights
- A manually configured MCP server
- A continuously running Skill
- The `codex.exe` backend process
- An ordinary `ChatGPT.exe` private-memory heap leak
- A single visible browser subprocess
- Codex cache files alone

On this specific machine, the strongest explanation is a graphics
shared-commit or hybrid-GPU driver-layer issue triggered while Codex
Desktop was running.

Updating the AMD Radeon 780M driver stopped the issue from reproducing
during the observation period.

## 19. Limitations

The investigation did not capture:

- Historical GPU Process Memory counters
- PoolMon allocation tags
- ETW GPU allocation traces
- A Windows kernel memory dump
- A driver verifier trace

Therefore, the investigation cannot identify one exact AMD, NVIDIA,
DirectX, or Windows driver module with absolute certainty.

The result should be treated as a documented case and a high-confidence
diagnosis, not as proof that every Codex memory issue has the same cause.

## 20. Recommended Troubleshooting Order

Users experiencing similar symptoms can try the following sequence:

1. Record system committed memory
2. Record available physical memory
3. Record total process-private memory
4. Record paged and nonpaged pool memory
5. Verify whether `ChatGPT.exe` actually grows
6. Verify whether `codex.exe` actually grows
7. Update the integrated GPU driver
8. Update the chipset driver
9. Restart Windows
10. Test Codex with the discrete GPU selected
11. Disable AMD, NVIDIA, and Razer overlays
12. Test with Hardware-Accelerated GPU Scheduling disabled
13. Capture GPU Process Memory counters if the issue continues

## 21. Evidence Files

- [Task Manager process view](../evidence/task-manager-processes.png)
- [Task Manager memory view](../evidence/task-manager-memory.png)
- [Monitoring summary](../evidence/memory-summary.csv)
- [Monitoring script](../scripts/monitor-memory-leak.ps1)
