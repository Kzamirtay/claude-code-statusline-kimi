# Установщик статус-строки Claude Code с лимитами Kimi.
# Копирует statusline.sh в ~/.claude и прописывает её вызов в settings.json.
#
# Установка:  powershell -ExecutionPolicy Bypass -File install.ps1
# Удаление:   powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall

[CmdletBinding()]
param(
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

$claudeDir    = Join-Path $HOME '.claude'
$scriptTarget = Join-Path $claudeDir 'statusline.sh'
$settingsFile = Join-Path $claudeDir 'settings.json'
$command      = 'bash "$HOME/.claude/statusline.sh"'

function Read-Settings {
    if (Test-Path $settingsFile) {
        $raw = Get-Content $settingsFile -Raw -Encoding UTF8
        if ($raw -and $raw.Trim()) { return ($raw | ConvertFrom-Json) }
    }
    return [pscustomobject]@{}
}

function Backup-Settings {
    if (Test-Path $settingsFile) {
        $backup = "$settingsFile.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $settingsFile $backup -Force
        return $backup
    }
    return $null
}

function Save-Settings($cfg) {
    $json = $cfg | ConvertTo-Json -Depth 100
    [System.IO.File]::WriteAllText($settingsFile, $json, (New-Object System.Text.UTF8Encoding($false)))
}

if ($Uninstall) {
    if (Test-Path $scriptTarget) { Remove-Item $scriptTarget -Force }
    $cfg = Read-Settings
    if ($cfg.PSObject.Properties.Name -contains 'statusLine') {
        $backup = Backup-Settings
        $cfg.PSObject.Properties.Remove('statusLine')
        Save-Settings $cfg
    }
    Write-Host 'Статус-строка удалена: скрипт и блок statusLine в settings.json убраны.'
    exit 0
}

# --- Проверка зависимостей ---
$missing = @()
foreach ($tool in 'bash', 'jq', 'curl') {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { $missing += $tool }
}
if ($missing) {
    Write-Host "Не найдены обязательные утилиты: $($missing -join ', ')" -ForegroundColor Red
    Write-Host 'Установите Git for Windows (bash) и jq: winget install jqlang.jq'
    exit 1
}

# --- Установка ---
New-Item -ItemType Directory -Force $claudeDir | Out-Null

$scriptSource = Join-Path $PSScriptRoot 'statusline.sh'
if (-not (Test-Path $scriptSource)) {
    Write-Host "Файл statusline.sh не найден рядом с install.ps1: $scriptSource" -ForegroundColor Red
    exit 1
}
Copy-Item $scriptSource $scriptTarget -Force

$cfg = Read-Settings
$backup = Backup-Settings

$statusLine = [pscustomobject]@{ type = 'command'; command = $command }
if ($cfg.PSObject.Properties.Name -contains 'statusLine') {
    $cfg.statusLine = $statusLine
} else {
    $cfg | Add-Member -NotePropertyName statusLine -NotePropertyValue $statusLine
}
Save-Settings $cfg

Write-Host 'Готово! Статус-строка установлена.' -ForegroundColor Green
Write-Host 'Пример: Claude Sonnet ██████░░░░ 68% │ 5h █░░░░░░░░░ 18% 4ч │ wk ████░░░░░░ 40% 5ч'
Write-Host 'Лимиты Kimi отображаются при заданной переменной окружения ANTHROPIC_API_KEY.'
if ($backup) { Write-Host "Резервная копия настроек: $backup" }
