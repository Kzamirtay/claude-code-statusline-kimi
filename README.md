# claude-code-statusline-kimi

Статус-строка для [Claude Code](https://claude.ai/code) на Windows: название модели, прогресс-бар использованного контекста и лимиты Kimi (5-часовой и недельный) с барами и временем до сброса.

```
Claude Sonnet ██████░░░░ 68% │ 5h █░░░░░░░░░ 18% 4ч │ wk ████░░░░░░ 40% 5ч
```

## Что показывает

- **Модель** — `display_name` текущей модели (голубым).
- **Бар контекста** — процент использованного контекстного окна, 10 сегментов. Цвет: зелёный < 50%, жёлтый 50–79%, красный ≥ 80%.
- **5h** — использование 5-часового лимита Kimi + время до его сброса.
- **wk** — использование недельного лимита + время до его сброса.

Время до сброса выводится в минутах (`41м`), часах (`4ч`) или днях (`2д`).

## Требования

- Windows + Claude Code.
- Git Bash (из Git for Windows) — Claude Code выполняет команду статус-строки через bash.
- jq — `winget install jqlang.jq`.
- curl — встроен в Windows 10+.
- Переменная окружения `ANTHROPIC_API_KEY` с ключом Kimi. Без неё блок лимитов просто не показывается — модель и бар контекста работают в любом случае.

## Установка

```powershell
git clone https://github.com/Kzamirtay/claude-code-statusline-kimi.git
cd claude-code-statusline-kimi
powershell -ExecutionPolicy Bypass -File install.ps1
```

Установщик:

- проверяет наличие `bash`, `jq`, `curl`;
- копирует `statusline.sh` в `~/.claude/`;
- создаёт резервную копию `settings.json` и прописывает в нём `statusLine.command = bash "$HOME/.claude/statusline.sh"`, не трогая остальные настройки.

## Как это работает

- Статус-строка перерисовывается Claude Code при событиях сессии (сообщения, вызовы инструментов).
- Лимиты запрашиваются у `https://api.kimi.com/coding/v1/usages` не чаще одного раза в 60 секунд — ответ кэшируется в `/tmp/claude_kimi_usage_cache.json`.
- При ошибке сети или парсинга блок лимитов скрывается, а при повторных ошибках API не дёргается на каждой перерисовке.
- Пороги цвета лимитов те же, что у бара контекста: зелёный < 50%, жёлтый 50–79%, красный ≥ 80%.

## Удаление

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall
```

Удаляет `~/.claude/statusline.sh` и блок `statusLine` из `settings.json` (с резервной копией).
