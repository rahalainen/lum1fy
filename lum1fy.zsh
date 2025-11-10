#!/usr/bin/env zsh
# ✧ lum1fy v1.4.0 ✧
# converts videos to AV1 (SVT-AV1) with progress bars, trimming, bitrate/CRF modes,
# Discord upload sizing, and optional audio merging
#
# ~ Usage ~
#   lum1fy [options] <file|directory>
#
# ~ Quality modes (mutually exclusive) ~
#   -q, --quality <crf>      CRF value (1..63, lower = higher quality) (default: $DEFAULT_CRF)
#   -b, --bitrate <bitrate>  target video bitrate (eg "2000k") (mutually exclusive with -q and --discord)
#   --discord <mode>         auto-calc bitrate for discord limits: free | basic | serverboost | nitro
#
# ~ Video options ~
#   -s, --speed <preset>     svt-av1 speed preset (0..13, lower = slower but better quality) (default: $DEFAULT_SPEED)
#   --start <secs>           trim start (seconds or hh:mm:ss), optional
#   --end <secs>             trim end (seconds or hh:mm:ss), optional
#   --merge-audio            mix multiple audio tracks to a single audio track
#
# ~ General options ~
#   --no-color               disable color output (NO_COLOR=1 also works)
#   -d, --dir                write outputs to 'av1-output/<name>.mp4' instead of '<name>-av1.mp4'
#   -y, --yes                force overwrite existing files & force re-encode in --discord mode (non-interactive)
#   -n, --no                 force skip existing files & in --discord mode if source file is smaller than the limit (non-interactive)
#   -r, --recursive          get videos recursively from given directories (default: false)
#   -v, --verbose            enable verbose logging (print info-level events)
#   -h, --help               show this help message
#
# ~ Examples ~
#   lum1fy -q 24 hq_video.mp4
#   lum1fy --bitrate 2000k -s 2 clip.mp4
#   lum1fy --discord basic --start 10 --end 40 --merge-audio ~/Videos/cool-clip.mp4
#   lum1fy --merge-audio -n .


## --- user defaults (configurable) --- ##
DEFAULT_SPEED=4
DEFAULT_CRF=30
MAX_bitrate_KBPS="12000"      # cap for calculated discord bitrate
MARGIN_KBPS="500"             # extra margin for discord bitrate (audio + overhead)
OUTPUT_DIR_NAME="av1-output"  # name for the output directory (still stored relative to input files!)


## --- runtime globals (do not touch) --- ##
total_time=0
total_in_size=0
total_out_size=0
processed_count=0
script_path="${(%):-%x}"
script_dir="$(dirname "$script_path")"
script_name="$(basename "$script_path")"
discord_mode=""
bitrate_mode=false
bitrate=""
start_s=0
end_s=0
merge_audio=false
force_overwrite=false
force_skip=false
verbose=false
output_dir_mode=false
recursive=false
input_files=()
quality_exclusive_count=0
yes_no_exclusive_count=0


## --- set colors --- ##
USE_COLOR=true
for arg in "$@"; do
  [[ "$arg" == "--no-color" ]] && USE_COLOR=false
done
[[ -n "$NO_COLOR" ]] && USE_COLOR=false

if $USE_COLOR && [[ -t 1 ]]; then
  GREEN="\033[32m"
  YELLOW="\033[33m"
  MAGENTA="\033[35m"
  CYAN="\033[36m"
  RED="\033[31m"
  BOLD="\033[1m"
  RESET="\033[0m"
else
  GREEN=""; YELLOW=""; MAGENTA=""; CYAN=""; RED=""; BOLD=""; RESET=""
fi

# set default colors for each log level
SUCCESS=$GREEN
INFO=$CYAN
WARNING=$YELLOW
ERROR=$RED
OTHER=$MAGENTA


## --- print helpers --- ##
show_help() {
  awk -v info_color="$INFO" -v reset="$RESET" -v crf="$DEFAULT_CRF" -v speed="$DEFAULT_SPEED" '
    BEGIN { printing=0 }
    /^# ~/{ printing=1 }                              # start printing at first "# ~" line
    printing {
      if ($0 !~ /^#/) exit                            # stop at first non-comment line
      line = $0
      sub(/^# ?/, "", line)                           # remove leading "# " or "#"
      gsub(/\$DEFAULT_CRF/, crf, line)                # replace $DEFAULT_CRF
      gsub(/\$DEFAULT_SPEED/, speed, line)            # replace $DEFAULT_SPEED
      if (line ~ /^~ /) line = info_color line reset  # color headers
      print line
    }
  ' "$script_path"
}

success() {
  local emojis=("◝(ᵔᗜᵔ)◜" "/ᐠ˵-⩊-˵マ" "(˶ˆ꒳ˆ˵)")
  local emoji="${emojis[RANDOM % ${#emojis[@]} + 1]}"
  if [[ "$USE_COLOR" != false ]]; then
    echo -e "${SUCCESS}[✓] ${emoji} | $*${RESET}"
  else
    echo "[✓] $*"
  fi
}

info() {
  if ! $verbose; then return; fi
  local emojis=("ᓚᘏᗢ" "/ᐠ-˕-マ" "/ᐠ. .ᐟ\Ⳋ")
  local emoji="${emojis[RANDOM % ${#emojis[@]} + 1]}"
  if [[ "$USE_COLOR" != false ]]; then
    echo -e "${INFO}[ℹ] ${emoji} | $*${RESET}"
  else
    echo "[ℹ] $*"
  fi
}

warning() {
  local emojis=("(˶°ㅁ°)!!" "(≖_≖ )" "(¬_¬\")")
  local emoji="${emojis[RANDOM % ${#emojis[@]} + 1]}"
  if [[ "$USE_COLOR" != false ]]; then
    echo -e "${WARNING}[⚠︎] ${emoji} | $*${RESET}"
  else
    echo "[⚠︎] $*"
  fi
}

error() {
  local emojis=("╥﹏╥" "/ᐠ╥˕╥マ")
  local emoji="${emojis[RANDOM % ${#emojis[@]} + 1]}"
  if [[ "$USE_COLOR" != false ]]; then
    echo -e "${ERROR}[×] ${emoji} | $*${RESET}"
  else
    echo "[×] $*"
  fi
}


## --- other helpers --- ##
# check if value is a number and optionally within a range
# usage: is_number_in_range VALUE [MIN] [MAX]
is_number_in_range() {
  local val="$1"
  local min="$2"
  local max="$3"

  [[ "$val" =~ '^[0-9]+$' ]] || return false
  [[ -n "$min" ]] && (( val <= min )) && return false
  [[ -n "$max" ]] && (( val >= max )) && return false
  return true
}

# prettify seconds to hours, minutes and seconds
# usage: format_duration SECONDS
format_duration() {
  local secs=$1
  local h=$((secs / 3600))
  local m=$(((secs % 3600) / 60))
  local s=$((secs % 60))
  if ((h > 0)); then
    printf "%dh %02dm %02ds" "$h" "$m" "$s"
  elif ((m > 0)); then
    printf "%dm %02ds" "$m" "$s"
  else
    printf "%ds" "$s"
  fi
}

# parse time string (hh:mm:ss or seconds) into seconds (integer)
parse_time_to_seconds() {
  local t="$1"
  if [[ -z "$t" ]]; then
    echo 0
    return
  fi
  if [[ "$t" =~ ^[0-9]+$ ]]; then
    echo "$t"
    return
  fi
  if [[ "$t" =~ ^([0-9]+):([0-9]{1,2}):([0-9]{1,2})$ ]]; then
    echo $(( ${match[1]} * 3600 + ${match[2]} * 60 + ${match[3]} ))
    return
  fi
  if [[ "$t" =~ ^([0-9]{1,2}):([0-9]{1,2})$ ]]; then
    echo $(( ${match[1]} * 60 + ${match[2]} ))
    return
  fi
  # fallback: return the original value
  echo "$t"
}

# get duration in seconds (floating) from ffprobe
get_duration() {
  local infile="$1"
  ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$infile" 2>/dev/null || echo 0
}

# calculate bitrate for discord mode
# usage: calculate_discord_bitrate LIMIT_MB CLIP_LENGTH
calculate_discord_bitrate() {
  local limit_mb="$1"
  local clip_len="$2"

  # target kbits = MB * 8 * 1000
  local target_kbits=$(( limit_mb * 8 * 1000 ))

  # calculate bitrate
  local bitrate_kbps=$(( target_kbits / clip_len - MARGIN_KBPS ))

  # cap by MAX_bitrate_KBPS if provided
  if (( MAX_bitrate_KBPS > 0 && bitrate_kbps > MAX_bitrate_KBPS )); then
    bitrate_kbps=$MAX_bitrate_KBPS
  fi

  echo "$bitrate_kbps"
  return 0
}

# build audio args (autodetect if merge requested)
build_audio_args() {
  local infile="$1"
  local merge_flag="$2"
  if ! $merge_flag; then
    echo "-c:a copy"
    return
  fi

  # count audio streams
  local stream_count
  stream_count=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$infile" 2>/dev/null | wc -l | tr -d ' ')
  if (( stream_count > 1 )); then
    # build amix for all audio streams
    echo "-filter_complex [0:a:0][0:a:1]amix=inputs=${stream_count}:duration=longest:normalize=0[aout] -map 0:v -map [aout]"
  else
    echo "-c:a copy"
  fi
}

# build ffmpeg args per file dynamically
build_ffmpeg_args() {
  local infile="$1"
  local outfile="$2"
  local start_s="$3"
  local end_s="$4"
  local args=()

  # set loglevel
  if ! $verbose; then
    args+=(-hide_banner -loglevel error)
  fi

  # progress + no stats + force override (we handle it natively)
  args+=(-progress pipe:1 -nostats -y)

  # clip start time
  if [[ -n "$start_s" ]]; then
    args+=(-ss "$start_s")
  fi

  # clip end time
  if [[ -n "$end_s" ]]; then
    args+=(-to "$end_s")
  fi

  # input file
  args+=(-i "$infile")

  # video args
  [[ -z "$SPEED" ]] && SPEED=$DEFAULT_SPEED
  [[ -z "$CRF" ]] && CRF=$DEFAULT_CRF

  if $bitrate_mode; then
    # explicit bitrate mode or discord calculated
    args+=(-c:v libsvtav1 -svtav1-params "no-progress=1:rc=1:tbr=${bitrate}:preset=${SPEED}")
  else
    # CRF mode
    args+=(-c:v libsvtav1 -svtav1-params "no-progress=1:rc=0:crf=${CRF}:preset=${SPEED}")
  fi

  # audio args
  args+=($(build_audio_args "$infile" $merge_audio))

  # output file
  args+=("$outfile")

  echo "${args[@]}"
}

# core encoder with progress
encode_with_progress() {
  local infile="$1"
  local outfile="$2"
  local start_s="$3"
  local end_s="$4"
  local clip_len="$5"

  # build ffmpeg command
  local ffmpeg_args
  ffmpeg_args=($(build_ffmpeg_args "$infile" "$outfile" "$start_s" "$end_s"))
  info "Running FFmpeg with command: '${RESET}ffmpeg $ffmpeg_args[@]${INFO}'\n"

  # run ffmpeg and pipe progress
  export SVT_LOG=1  # sets SVT log level to [error]
  ffmpeg "${ffmpeg_args[@]}" | awk -v dur="$clip_len" -v c1=$RED -v c2=$YELLOW -v c3=$GREEN -v RESET=$RESET '
    BEGIN { bar_len = 32 }
    /^out_time_ms=/ {
      gsub(/out_time_ms=/, "")
      prog = $1 / (dur * 1000000)
      if (prog > 1) prog = 1
      filled = int(prog * bar_len)

      # choose color
      if (prog <= 0.33) color=c1
      else if (prog <= 0.66) color=c2
      else color=c3

      # print colored bar
      printf "\r["
      for (i=0; i<filled; i++) printf "%s■%s", color, RESET
      for (i=filled; i<bar_len; i++) printf " "
      printf "] %3d%%", int(prog*100)
      fflush()
    }
    END { print "" }
  '
}

# process a single file
process_file() {
  local infile="$1"
  local base=${infile:t:r}
  local dir=${infile:h}
  local outfile

  if $output_dir_mode; then
    mkdir -p $OUTPUT_DIR_NAME
    outfile="${dir}/$OUTPUT_DIR_NAME/${base}.mp4"
  else
    outfile="${dir}/${base}-av1.mp4"
  fi

  echo ""
  echo "${INFO}✧ lum1fying ${RESET}${infile} (${count}/${total}) ${INFO}✧${RESET}"
  local start=$(date +%s)
  local in_size=$(stat -c%s "$infile" 2>/dev/null || stat -f%z "$infile")

  # get start time and end time
  (( $end_s <= 0 )) && end_s=$(get_duration "$infile")

  # compute clip length (seconds)
  local clip_len=$(( end_s - start_s ))
  if (( clip_len <= 0 )); then
    error "Trimmed length is zero or negative!"
    return 1
  fi

  # handle --discord auto bitrate: compute per-file (uses trimmed length)
  if [[ -n "$discord_mode" ]]; then
    # get filesize limit
    local limit_mb
    case "$discord_mode" in
      free)  limit_mb=10 ;;
      basic) limit_mb=50 ;;
      serverboost) limit_mb=100 ;;
      nitro) limit_mb=500 ;;
      *)
        error "Unknown discord mode '$discord_mode'!"
        return 1
        ;;
    esac

    # pass start/end seconds into calculator
    bitrate=$(calculate_discord_bitrate "$limit_mb" "$clip_len") || { error "Discord bitrate calc failed!"; return 1; }
    bitrate_mode=true
    if (( in_size < bitrate * clip_len / 8 * 1000 )) && ! $force_overwrite; then
      if $force_skip; then
        warning "Skipping '${RESET}$infile${WARNING}' (output exists)..."
        return 2
      fi

      printf "Source file is only %.1f MB! Continuing with '--discord %s' would re-encode to ~%.1f MB. Continue anyway? [y/N] " \
        "$(awk "BEGIN{printf \"%.1f\", $in_size/1000000}")" \
        "$discord_mode" \
        "$limit_mb"
      read -r answer
      [[ $answer != [Yy]* ]] && { warning "Skipping '${RESET}$infile${WARNING} (canceled)..."; return 2 }
    fi
    info "Discord mode '$discord_mode' selected: bitrate will be ${bitrate} kbps!"
  fi

  # check if file exists (better error handling than native ffmpeg)
  if [[ -f "$outfile" ]] && ! $force_overwrite; then
    if $force_skip; then
      warning "Skipping '${RESET}$infile${WARNING}' (output exists)..."
      return 2
    fi

    # interactive
    echo -n "File '$outfile' already exists. Overwrite? [y/N] "
    read -r ans
    if [[ $ans != [Yy]* ]]; then
      warning "Skipping '${RESET}$infile${WARNING}' (output exists)..."
      return 2
    fi
  fi

  # run encoder
  encode_with_progress "$infile" "$outfile" "$start_s" "$end_s" "$clip_len"
  ffmpeg_exit=${pipestatus[1]}  # 1 = first command in the pipe
  if (( ffmpeg_exit != 0 )); then
    error "FFmpeg failed with code $ffmpeg_exit"
    return 1
  fi

  local end=$(date +%s)
  local elapsed=$(( end - start ))
  local took=$(format_duration "$elapsed")

  local out_size=$(stat -c%s "$outfile" 2>/dev/null || stat -f%z "$outfile")
  local out_size_mb=$(awk "BEGIN {printf \"%.1f\", $out_size / 1000000}")

  local diff=$(( out_size - in_size ))
  local diff_mb=$(awk "BEGIN {printf \"%.1f\", $diff / 1000000}")

  local percentage=0
  if (( in_size > 0 )); then
    percentage=$(awk "BEGIN {printf \"%.1f\", ($out_size / $in_size) * 100}")
  fi

  local msg
  if (( diff < 0 )); then
    msg="${SUCCESS}shrunk by ${RESET}${diff_mb#-} MB ${SUCCESS}/${RESET} ${percentage}%"
  elif (( diff > 0 )); then
    msg="${WARN}grew by ${RESET}${diff_mb} MB ${WARN}/${RESET} ${percentage}%"
  else
    msg="${INFO}same size as input!"
  fi

  success "Done:${RESET} $outfile  ${SUCCESS}(took ${RESET}$took${SUCCESS}, output size ${RESET}${out_size_mb} MB${SUCCESS}, $msg ${SUCCESS}of original)"

  total_time=$(( total_time + elapsed ))
  total_in_size=$(( total_in_size + in_size ))
  total_out_size=$(( total_out_size + out_size ))
  processed_count=$(( processed_count + 1 ))
}


## --- check dependencies --- ##
# ensure dependencies
for cmd in ffmpeg ffprobe awk stat; do
  if ! command -v $cmd >/dev/null 2>&1; then
    error "Required command '$cmd' not found in PATH!"
    exit 1
  fi
done


## --- parse args (long + short) --- ##
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--speed)
      if ! is_number_in_range "$2" 0 13; then
        error "$1 requires a speed value (0..13)!"
        exit 1
      fi
      SPEED="$2"; shift 2
      ;;
    -q|--quality)
      info "$2"
      if ! is_number_in_range "$2" 1 63; then
        error "$1 requires a CRF value (1..63)!"
        exit 1
      fi
      ((quality_exclusive_count++)); CRF="$2"; shift 2
      ;;
    -b|--bitrate)
      if [[ -z "$2" || ! "$2" =~ ^[0-9]+([bkm])?$ ]]; then
        error "$1 requires a bitrate value (e.g. 2000k)!"
        exit 1
      fi
      ((quality_exclusive_count++)); bitrate_mode=true; bitrate="$2"; shift 2
      ;;
    --discord)
      if [[ -z "$2" ]]; then
        error "$1 requires a mode: 'free', 'basic', 'serverboost', or 'nitro'"
        exit 1
      fi
      ((quality_exclusive_count++)); discord_mode="$2"; shift 2
      ;;
    --start)
      if ! is_number_in_range "$2" 0 ""; then
        error "$1 requires a start time (seconds)"
        exit 1
      fi
      start_s=$(parse_time_to_seconds "$2"); shift 2
      ;;
    --end)
      if ! is_number_in_range "$2" 0 ""; then
        error "$1 requires an end time (seconds)"
        exit 1
      fi
      end_s=$(parse_time_to_seconds "$2"); shift 2
      ;;
    --merge-audio) merge_audio=true; shift ;;
    --no-color) shift ;;
    -d|--dir) output_dir_mode=true; shift ;;
    -y|--yes) ((yes_no_exclusive_count++)); force_overwrite=true; shift ;;
    -n|--no) ((yes_no_exclusive_count++)); force_skip=true; shift ;;
    -r|--recursive) recursive=true; shift ;;
    -v|--verbose) verbose=true; shift ;;
    -h|--help) show_help; exit 0 ;;
    --) shift; break ;;
    -*) error "Unknown option: '$1'"; show_help; exit 1 ;;
    *) input_files+=("$1"); shift ;;
  esac
done

# sanity check
if (( ${#input_files[@]} == 0 )); then
  error "No input files or directories provided!"
  exit 1
fi

# mutual exclusivity checks
if (( quality_exclusive_count > 1 )); then
  error "Whoa there! --quality, --bitrate, and --discord are mutually exclusive - pick just one!"
  exit 1
elif (( yes_no_exclusive_count > 1 )); then
  error "Whoa there! --yes and --no are mutually exclusive - pick just one!"
  exit 1
fi


## --- main logic --- ##
files=()

# collect files
for inpath in "${input_files[@]}"; do
  if [ -d "$inpath" ]; then
    if [ "$recursive" = true ]; then
      # recursively find matching files
      while IFS= read -r -d '' f; do
        files+=("$f")
      done < <(find "$inpath" -type f \( -iname '*.mp4' -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.webm' \) -print0)
    else
      # non-recursive glob (nullglob-safe)
      dirfiles=("$inpath"/*.{mp4,mkv,mov,webm}(.N))
      files+=("${dirfiles[@]}")
    fi
  elif [ -f "$inpath" ]; then
    files+=("$inpath")
  else
    warn "Skipping invalid input: $inpath"
  fi
done

# filter out any that end with -av1.mp4
filtered=()
for f in "${files[@]}"; do
  [[ "$f" == *-av1.mp4 ]] && continue
  filtered+=("$f")
done
files=("${filtered[@]}")

total=${#files[@]}
if (( total == 0 )); then
  error "No supported files found!"
  exit 1
fi

# process everything
count=0
for f in "${files[@]}"; do
  ((count++))
  process_file "$f" "$count" "$total"
done

# --- summary ---
if (( processed_count > 0 )); then
  total_time_str=$(format_duration "$total_time")
  total_in_size_mb=$(awk "BEGIN {printf \"%.1f\", $total_in_size / 1000000}")
  total_out_size_mb=$(awk "BEGIN {printf \"%.1f\", $total_out_size / 1000000}")
  total_diff=$(( total_out_size - total_in_size ))
  total_diff_mb=$(awk "BEGIN {printf \"%.1f\", $total_diff / 1000000}")
  total_percentage=0
  if (( total_in_size > 0 )); then
    total_percentage=$(awk "BEGIN {printf \"%.1f\", ($total_out_size / $total_in_size) * 100}")
  fi

  msg=""
  if (( total_diff < 0 )); then
    msg="Shrunk by ${RESET}${total_diff_mb#-} MB ${OTHER}/${RESET} ${total_percentage}% of original"
  elif (( total_diff > 0 )); then
    msg="Grew by ${RESET}${total_diff_mb} MB ${OTHER}/${RESET} ${total_percentage}% of original"
  else
    msg="Same size as input!"
  fi

  echo ""
  echo "${INFO}✧ ${BOLD}All done in ${RESET}${total_time_str}${INFO}${BOLD}! ${RESET}${processed_count} ${INFO}${BOLD}file(s) processed ${RESET}${INFO}✧${RESET}"
  echo "${OTHER}   Total input size:${RESET} ${total_in_size_mb} MB"
  echo "${OTHER}   Total output size:${RESET} ${total_out_size_mb} MB"
  echo "${OTHER}   ${msg}${RESET}"
  echo ""
  echo "${INFO}✧ Have a good day! (˶˃ ᵕ ˂˶) ✧${RESET}"
else
  error "No files processed!"
fi
