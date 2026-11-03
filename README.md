# dotfiles-light

Мої налаштування для робочих і чужих комп'ютерів: Neovim, VS Code, kanata.
Без sudo, без секретів. Це дзеркало, його щодня оновлює скрипт backup-config
з мого ноутбука. Правити треба реальні конфіги в ~/.config/..., а не файли тут.

## Linux / macOS

    git clone https://github.com/dotsenko-dev/dotfiles-light.git
    cd dotfiles-light && ./setup.sh

Скрипт спершу зберігає старі файли в ~/.dotfiles-light-backup-ДАТА.
Neovim треба встановити окремо (nvim має бути в PATH).

## Windows

setup.sh не працює. Вручну:
- nvim/init.lua покласти в %LOCALAPPDATA%\nvim\init.lua
- vscode/settings.json і keybindings.json покласти в %APPDATA%\Code\User\
- розширення: кожен рядок з vscode/extensions.txt встановити командою
  code --install-extension <рядок>

## kanata

Конфіг kanata/kanata.kbd кладеться на місце, але kanata НЕ запускається.
Спершу спитати в IT, чи дозволена така програма (вона перехоплює клавіатуру).
