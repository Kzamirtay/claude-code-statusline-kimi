#!/usr/bin/env bash
# Установщик статус-строки Claude Code с лимитами Kimi (Linux).
# Копирует statusline.sh в ~/.claude и прописывает её вызов в settings.json.
#
# Установка одной командой:
#   curl -fsSL https://raw.githubusercontent.com/Kzamirtay/claude-code-statusline-kimi/main/install.sh | bash
# Удаление:
#   curl -fsSL https://raw.githubusercontent.com/Kzamirtay/claude-code-statusline-kimi/main/install.sh | bash -s -- --uninstall

set -u

REPO_RAW='https://raw.githubusercontent.com/Kzamirtay/claude-code-statusline-kimi/main'
CLAUDE_DIR="$HOME/.claude"
SCRIPT_TARGET="$CLAUDE_DIR/statusline.sh"
SETTINGS="$CLAUDE_DIR/settings.json"
COMMAND='bash "$HOME/.claude/statusline.sh"'

# --- Проверка зависимостей ---
missing=''
for tool in jq curl; do
    command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
done
if [ -n "$missing" ]; then
    echo "Не найдены обязательные утилиты:$missing" >&2
    echo "Установите их, например: sudo apt install$missing  (или dnf / yum / brew)" >&2
    exit 1
fi

# set_status_line [del] — прописать вызов статус-строки в settings.json (del — удалить блок).
# Остальные настройки не трогаем, перед записью делаем резервную копию.
set_status_line() {
    local mode="${1:-set}"
    local tmp="$SETTINGS.tmp-$$"
    if [ -f "$SETTINGS" ] && [ -s "$SETTINGS" ] && ! jq -e . "$SETTINGS" >/dev/null 2>&1; then
        echo "Внимание: $SETTINGS не является валидным JSON — файл не тронут, правьте вручную." >&2
        return 1
    fi
    [ -f "$SETTINGS" ] && cp "$SETTINGS" "$SETTINGS.bak-$(date +%Y%m%d-%H%M%S)"
    if [ "$mode" = 'del' ]; then
        if [ -f "$SETTINGS" ] && [ -s "$SETTINGS" ]; then
            jq 'del(.statusLine)' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
        fi
        return 0
    fi
    if [ -f "$SETTINGS" ] && [ -s "$SETTINGS" ]; then
        jq --arg cmd "$COMMAND" '.statusLine = {type: "command", command: $cmd}' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
    else
        jq -n --arg cmd "$COMMAND" '{statusLine: {type: "command", command: $cmd}}' > "$SETTINGS"
    fi
}

if [ "${1:-}" = '--uninstall' ]; then
    rm -f "$SCRIPT_TARGET"
    set_status_line del
    echo 'Статус-строка удалена: скрипт и блок statusLine в settings.json убраны.'
    exit 0
fi

# --- Установка ---
mkdir -p "$CLAUDE_DIR"

# statusline.sh: из каталога установщика (склонированный репозиторий) или скачать (curl | bash)
SRC_DIR=''
if [ -n "${BASH_SOURCE[0]:-}" ] && [ "${BASH_SOURCE[0]}" != 'bash' ] && [ "${BASH_SOURCE[0]}" != '-' ]; then
    SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
fi
if [ -n "$SRC_DIR" ] && [ -f "$SRC_DIR/statusline.sh" ]; then
    cp "$SRC_DIR/statusline.sh" "$SCRIPT_TARGET"
else
    curl -fsSL "$REPO_RAW/statusline.sh" -o "$SCRIPT_TARGET"
fi
chmod +x "$SCRIPT_TARGET"

set_status_line

echo 'Готово! Статус-строка установлена.'
echo 'Пример: Claude Sonnet ██████░░░░ 68% │ 5h █░░░░░░░░░ 18% 4ч │ wk ████░░░░░░ 40% 5ч'
echo 'Лимиты Kimi отображаются при заданной переменной окружения ANTHROPIC_API_KEY.'
