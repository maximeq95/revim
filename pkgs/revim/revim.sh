# revim — Neovim, and an IDE around it: yazi and Neovim side by side in a zellij tab.
#   revim [DIR]             the IDE on DIR: a new tab inside zellij, else the `revim-<dir>` session
#   revim FILE...           edit, as `nvim FILE...` (anything but a lone directory)
#   revim git [DIR]         lazygit, in a tab of its own inside zellij
#   revim grep [QUERY]      live ripgrep search; Enter opens the match in the tab's Neovim
#   revim find              pick a file (fd + fzf); Enter opens it in the tab's Neovim
#   revim open FILE [LINE]  open FILE (at LINE) in the tab's Neovim and focus it
#   revim nvim [ARG...]     the tab's Neovim, serving the tab's socket (layout.kdl)

# The layout, yazi and the pickers call back into `revim`.
PATH=${0%/*}:$PATH

tab_id() {
  zellij action list-panes --tab --json |
    jq -r --argjson pane "$ZELLIJ_PANE_ID" '.[] | select(.id == $pane and (.is_plugin | not)) | .tab_id'
}

# One Neovim per tab, so that a session can hold several IDE tabs.
socket() {
  if [[ -n ${ZELLIJ_PANE_ID:-} ]]; then
    echo "${XDG_RUNTIME_DIR:-/tmp}/revim-$ZELLIJ_SESSION_NAME-$(tab_id).sock"
  fi
}

case ${1:-} in
git)
  dir=$(realpath -- "${2:-.}")
  [[ -z ${ZELLIJ:-} ]] || exec zellij action new-tab --name "git: ${dir##*/}" --cwd "$dir" --close-on-exit -- lazygit >/dev/null
  exec lazygit --path "$dir"
  ;;
grep)
  shift
  rg='rg --column --line-number --no-heading --color=always --smart-case'
  exec fzf --ansi --disabled --query "$*" --delimiter : \
    --bind "start:reload:$rg {q} || true" \
    --bind "change:reload:sleep 0.1; $rg {q} || true" \
    --bind 'enter:become(revim open {1} {2})' \
    --preview 'bat --color=always --highlight-line {2} -- {1}' \
    --preview-window 'right:60%,+{2}+3/3,border-left'
  ;;
find)
  fd --type f --hidden --follow --exclude .git |
    fzf --preview 'bat --color=always -- {}' --preview-window 'right:60%,border-left' \
      --bind 'enter:become(revim open {})'
  ;;
open)
  [[ -n ${2:-} ]] || exit 0
  file=$(realpath -- "$2")
  line=${3:-}
  sock=$(socket)
  [[ -S $sock ]] || exec nvim "$file" ${line:+"+$line"}
  nvim --server "$sock" --remote-expr 'v:lua.RevimFocus()' >/dev/null
  nvim --server "$sock" --remote "$file"
  [[ -z $line ]] || nvim --server "$sock" --remote-expr "cursor($line, 1)" >/dev/null
  ;;
nvim)
  shift
  zellij action rename-tab --tab-id "$(tab_id)" "revim: ${PWD##*/}" || true
  exec nvim --listen "$(socket)" --cmd 'let g:revim_ide = 1' "$@"
  ;;
*)
  [[ $# -le 1 && -d ${1:-.} ]] || exec nvim "$@"
  dir=$(realpath -- "${1:-.}")
  [[ -z ${ZELLIJ:-} ]] || exec zellij action new-tab --layout "$REVIM_LAYOUT" --cwd "$dir" >/dev/null
  cd -- "$dir"
  session=revim-${dir##*/}
  # A dead session would resurrect without running its commands: start it afresh.
  # (`delete-session` leaves a running one alone.)
  zellij delete-session "$session" &>/dev/null || true
  if zellij list-sessions --short 2>/dev/null | grep -qxF -- "$session"; then
    exec zellij attach "$session"
  fi
  exec zellij --session "$session" --new-session-with-layout "$REVIM_LAYOUT"
  ;;
esac
