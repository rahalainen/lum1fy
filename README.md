# ✧ lum1fy ✧
AV1 video converter script using Zsh and FFmpeg

Converts videos to AV1 (SVT-AV1) with CRF/bitrate/Discord-auto-calc encoding modes, start/end trimming, and audio stream merging.

###### NOTE: this is just a quick hobby project, the code is kinda messy

---
## Usage

```bash
lum1fy [options] <file|directory>
```
---

## Quality modes (mutually exclusive)

Choose one of these modes: (default: `-q`)

| Option | Description |
|------|-------------|
| `-q, --quality <crf>` | **Constant Quality mode** - CRF value (1-63, lower = higher quality) |
| `-b, --bitrate <bitrate>` | **Average Bitrate mode** - Target video bitrate (e.g., 2000k) |
| `--discord <mode>` | **Discord Auto-Calc** mode - Optimizes for Discord limits; <a href=#modes-for-discord-auto-calc>see table below</a> |

### Modes for Discord Auto-Calc
| Mode | Output size target | Description |
|------|--------------------|-------------|
| `free` | 10 MB | Free Discord account and no server boosts |
| `basic` | 50 MB | Discord Nitro Basic or Level 2 Server Boost perk |
| `serverboost` | 100 MB | Level 3 Server Boost perk |
| `nitro` | 500 MB | Discord Nitro |

---

## Options

- All of these go to `[options]`

### Video options
| Option | Description |
|--------|-------------|
| `-s, --speed <preset>` | SVT-AV1 speed preset (0-13, lower = slower but better quality) |
| `--start <secs>` | Trim start (seconds or hh:mm:ss) |
| `--end <secs>` | Trim end (seconds or hh:mm:ss) |
| `--merge-audio` | Mix multiple audio tracks into a single audio track |

### General options
| Option | Description |
|--------|-------------|
| `--no-color` | Disable color output (NO_COLOR=1 also works) |
| `-d, --dir` | Write outputs to `av1-output/<name>.mp4` instead of `<name>-av1.mp4` |
| `-y, --yes` | Force overwrite existing files & force re-encode in `--discord` mode (non-interactive) |
| `-n, --no` | Force skip existing files & in `--discord` mode if source file is smaller than the limit (non-interactive) |
| `-r, --recursive` | Get videos recursively from given directories |
| `-v, --verbose` | Enable verbose logging (print info-level events) |
| `-h, --help` | Show this help message |

---

## Examples

```bash
lum1fy -q 24 hq_video.mp4  
lum1fy --bitrate 2000k -s 2 clip.mp4  
lum1fy --discord basic --start 10 --end 40 --merge-audio ~/Videos/cool-clip.mp4  
lum1fy --merge-audio .
```
---

## Changelog

<details>
  <summary> ✧ v1.4.0 — Improved stats printing, added force-skip mode ✧ </summary>
  
  - Added `-n/--no` option for non-interactive skip (skip version of `-y`)
  - Improved stats printing
  - Changed Discord bitrate limit from 16 → 12 mbps
  - Misc bug fixes and README improvements
</details>

<details>
  <summary> ✧ v1.3.0 — Some refactoring, usability improvements ✧ </summary>
  
  - Added `--no-color` option  
  - Added `-y/--yes` for non-interactive overwrite & Discord re-encode  
  - Verbose logging (-v/--verbose)  
  - Warnings when Discord re-encode would inflate small source files  
  - Misc bug fixes and stability improvements
</details>

<details>
  <summary> ✧ v1.2.0 — Added Discord auto-calc ✧ </summary>
  
  - Added Discord-specific bitrate mode  
  - Added output directory option (-d)  
  - Improved trimming handling
  - Enhanced progress display
</details>
  
<details>
  <summary> ✧ v1.1.0 — First improvements ✧ </summary>
  
  - Added bitrate (VBR) mode 
  - Added progress bars
  - Support for audio track merging
</details>

<details>
  <summary> ✧ v1.0.0 — Initial script ✧ </summary>
  
  - Basic AV1 conversion, trimming, and CRF mode
</details>
