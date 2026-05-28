#!/bin/sh
# Claude Code status line — p10k lean style
# LEFT:  dir │ vcs │ model(effort) │ context bar
# RIGHT: 5h rate limit (right-aligned)

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')

# Effort level: try JSON input first, fall back to settings.json
effort=$(echo "$input" | jq -r '.effort_level // .effortLevel // empty')
[ -z "$effort" ] && effort=$(jq -r '.effortLevel // empty' ~/.claude/settings.json 2>/dev/null)

# Context window
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
inp_tok=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
out_tok=$(echo "$input" | jq -r '.context_window.current_usage.output_tokens // 0')
cc_tok=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
cr_tok=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Rate limits (5h only)
rl_5h=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
rl_5h_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')

# Shorten path: $HOME → ~
home="$HOME"
short_cwd="${cwd/#$home/\~}"

# Git branch
branch=""
if git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
  [ -z "$branch" ] && branch=$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
fi

# ══════════════════════════════════════════
# Build LEFT side
# ══════════════════════════════════════════
left=""
left_len=0

# dir
left="${left}\033[36m${short_cwd}\033[0m"
left_len=$((left_len + ${#short_cwd}))

# git branch
if [ -n "$branch" ]; then
  left="${left}  \033[33m\xef\x9c\xa9 ${branch}\033[0m"
  left_len=$((left_len + 2 + 2 + ${#branch}))  # 2 spaces + icon(2) + branch
fi

# model + effort
model_str="$model"
[ -n "$effort" ] && model_str="${model}(${effort})"
left="${left}  \033[34m${model_str}\033[0m"
left_len=$((left_len + 2 + ${#model_str}))

# context bar
if [ "$ctx_size" -gt 0 ] 2>/dev/null; then
  bar=$(awk -v size="$ctx_size" -v inp="$inp_tok" -v cc="$cc_tok" -v cr="$cr_tok" -v out="$out_tok" '
    BEGIN {
      W = 20
      inp_w = int(inp / size * W + 0.5)
      cc_w  = int(cc  / size * W + 0.5)
      cr_w  = int(cr  / size * W + 0.5)
      out_w = int(out / size * W + 0.5)
      if (inp > 0 && inp_w == 0) inp_w = 1
      if (cc  > 0 && cc_w  == 0) cc_w  = 1
      if (cr  > 0 && cr_w  == 0) cr_w  = 1
      if (out > 0 && out_w == 0) out_w = 1
      total = inp_w + cc_w + cr_w + out_w
      if (total > W) {
        f = W / total
        inp_w = int(inp_w * f); cc_w = int(cc_w * f)
        cr_w  = int(cr_w  * f); out_w = int(out_w * f)
        total = inp_w + cc_w + cr_w + out_w
      }
      free_w = W - total
      s = ""
      for (i = 0; i < inp_w; i++) s = s "\033[36m█\033[0m"
      for (i = 0; i < cc_w;  i++) s = s "\033[33m█\033[0m"
      for (i = 0; i < cr_w;  i++) s = s "\033[32m█\033[0m"
      for (i = 0; i < out_w; i++) s = s "\033[35m█\033[0m"
      for (i = 0; i < free_w;i++) s = s "\033[90m░\033[0m"
      printf "%s", s
    }
  ')

  pct_str=""
  if [ -n "$used_pct" ]; then
    u=${used_pct%.*}
    if [ "$u" -ge 70 ] 2>/dev/null; then
      pct_str="\033[31m${u}%\033[0m"
    elif [ "$u" -ge 40 ] 2>/dev/null; then
      pct_str="\033[33m${u}%\033[0m"
    else
      pct_str="\033[32m${u}%\033[0m"
    fi
    pct_vis_len=$((${#u} + 1))  # digits + %
  else
    pct_vis_len=0
  fi

  left="${left}  ${bar}"
  left_len=$((left_len + 2 + 20))  # 2 spaces + 20 bar chars

  if [ -n "$pct_str" ]; then
    left="${left} ${pct_str}"
    left_len=$((left_len + 1 + pct_vis_len))
  fi
fi

# ══════════════════════════════════════════
# Build RIGHT side (5h rate limit)
# ══════════════════════════════════════════
right=""
right_len=0

if [ -n "$rl_5h" ]; then
  now=$(date +%s)
  v=${rl_5h%.*}
  if [ "$v" -ge 80 ] 2>/dev/null; then c=31
  elif [ "$v" -ge 50 ] 2>/dev/null; then c=33
  else c=32; fi
  label="5h:${v}%"
  if [ -n "$rl_5h_reset" ] && [ "$rl_5h_reset" != "null" ] 2>/dev/null; then
    rem=$(( rl_5h_reset - now ))
    if [ "$rem" -gt 0 ] 2>/dev/null; then
      h=$(( rem / 3600 ))
      m=$(( (rem % 3600) / 60 ))
      if [ "$h" -gt 0 ]; then
        label="5h:${v}%(${h}h${m}m)"
      else
        label="5h:${v}%(${m}m)"
      fi
    fi
  fi
  right="\033[${c}m${label}\033[0m"
  right_len=${#label}
fi

# ══════════════════════════════════════════
# Output: left + padding + right
# ══════════════════════════════════════════
cols=$(tput cols 2>/dev/null || echo 120)
pad=$((cols - left_len - right_len))
[ "$pad" -lt 2 ] && pad=2

printf '%b' "$left"
printf '%*s' "$pad" ""
printf '%b' "$right"
