# ✧ lum1fy ✧
AV1 video converter script using Zsh and FFmpeg

Converts videos to AV1 (SVT-AV1) with progress bars, trimming, bitrate/CRF modes, Discord upload sizing, and optional audio merging.

---
## Usage

```bash
lum1fy [options] <file|directory>
```
---

## Quality options (mutually exclusive)

Choose one of these modes: (default: `-q`)
  
| Mode | Option | Description |
|------|--------|-------------|
| Constant Quality | `-q, --quality <crf>` | CRF value (1-63, lower = higher quality) (default: 30) |
| Average Bitrate | `-b, --bitrate <bitrate>` | Target video bitrate (e.g., 2000k) (mutually exclusive with `-q` and `--discord`) |
| Discord Auto-Calc | `--discord <mode>` | Automatically calculates bitrate for Discord limits; <a href=#modes-for-discord-auto-calc>see table below</a> |

### Modes for Discord Auto-Calc
| Mode | Output size target | Description |
|------|--------------------|-------------|
| `free` | 10 MB | Free Discord account & no server boosts |
| `basic` | 50 MB | Discord Nitro Basic & Level 2 Server Boost perk |
| `serverboost` | 100 MB | Level 3 Server Boost perk |
| `nitro` | 500 MB | Discord Nitro (full) |

---

## Options

- All of these go to `[options]`
  
| Option | Description |
|--------|-------------|
| `-s, --speed <preset>` | SVT-AV1 speed preset (0-13, lower = slower but better quality) (default: 4) |
| `--start <secs>` | Trim start (seconds or hh:mm:ss), optional |
| `--end <secs>` | Trim end (seconds or hh:mm:ss), optional |
| `--merge-audio` | Mix multiple audio tracks into a single audio track |
| `--no-color` | Disable color output (NO_COLOR=1 also works) |
| `-y, --yes` | Force overwrite existing files & force re-encode in `--discord` mode (non-interactive) |
| `-v, --verbose` | Enable verbose logging (print info-level events) |
| `-d, --dir` | Write outputs to `av1-output/<name>.mp4` instead of `<name>-av1.mp4` |
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
