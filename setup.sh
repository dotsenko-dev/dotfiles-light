#!/usr/bin/env bash
# Розкладає особисті налаштування (nvim, VS Code, kanata) без sudo.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/.dotfiles-light-backup-$(date +%F-%H%M%S)"

case "$(uname -s)" in
  Darwin) VSCODE_USER="$HOME/Library/Application Support/Code/User" ;;
  *)      VSCODE_USER="$HOME/.config/Code/User" ;;
esac

# зберігає копію існуючого файлу/папки перед заміною
backup() {
  [ -e "$1" ] || return 0
  mkdir -p "$BACKUP/$2"
  cp -a "$1" "$BACKUP/$2/"
}

echo "== Neovim =="
backup "$HOME/.config/nvim" nvim
mkdir -p "$HOME/.config/nvim"
cp -a "$HERE/nvim/." "$HOME/.config/nvim/"

echo "== VS Code =="
mkdir -p "$VSCODE_USER"
backup "$VSCODE_USER/settings.json" vscode
backup "$VSCODE_USER/keybindings.json" vscode
cp "$HERE/vscode/settings.json" "$HERE/vscode/keybindings.json" "$VSCODE_USER/"
if command -v code >/dev/null 2>&1; then
  while read -r ext; do
    [ -n "$ext" ] && code --install-extension "$ext" || true
  done < "$HERE/vscode/extensions.txt"
else
  echo "Команди 'code' нема, розширення пропущено."
fi

echo "== kanata (тільки конфіг, не запускається) =="
backup "$HOME/.config/kanata" kanata
mkdir -p "$HOME/.config/kanata"
cp "$HERE/kanata/kanata.kbd" "$HOME/.config/kanata/"

echo "Готово."
[ -d "$BACKUP" ] && echo "Попередні файли збережено в $BACKUP"
echo "Kanata запускай лише якщо це дозволено політикою компанії."
