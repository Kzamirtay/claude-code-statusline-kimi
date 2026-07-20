#!/usr/bin/env bash
# Статус-строка Claude Code: модель, бар контекста, лимиты Kimi (5-часовой / недельный).
# Вызывается из ~/.claude/settings.json (statusLine.command), JSON сессии приходит на stdin.

input=$(cat)
model=$(echo "$input" | jq -r '.model.display_name')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# --- Модель + прогресс-бар использованного контекста ---
if [ -n "$used" ]; then
    u=$(printf '%.0f' "$used")
    [ "$u" -gt 100 ] && u=100
    f=$((u / 10)); e=$((10 - f)); bar=''
    i=0; while [ $i -lt $f ]; do bar="${bar}█"; i=$((i + 1)); done
    i=0; while [ $i -lt $e ]; do bar="${bar}░"; i=$((i + 1)); done
    if [ "$u" -ge 80 ]; then c=31; elif [ "$u" -ge 50 ]; then c=33; else c=32; fi
    printf '\033[36m%s\033[0m \033[%dm%s\033[0m %s%%' "$model" "$c" "$bar" "$u"
else
    printf '\033[36m%s\033[0m' "$model"
fi

# --- Лимиты Kimi: кэш на 60 секунд, чтобы не дёргать API на каждую перерисовку ---
cache=/tmp/claude_kimi_usage_cache.json
fresh=0
if [ -f "$cache" ]; then
    now=$(date +%s)
    mt=$(stat -c %Y "$cache" 2>/dev/null)
    [ -n "$mt" ] && [ $((now - mt)) -lt 60 ] && fresh=1
fi
if [ "$fresh" -eq 0 ] && [ -n "$ANTHROPIC_API_KEY" ]; then
    resp=$(curl -s -m 3 -H "Authorization: Bearer $ANTHROPIC_API_KEY" "https://api.kimi.com/coding/v1/usages" 2>/dev/null)
    if printf '%s' "$resp" | jq -e '.usage' >/dev/null 2>&1; then
        printf '%s' "$resp" > "$cache"
    elif [ ! -f "$cache" ]; then
        : > "$cache"  # throttle: при ошибке не долбить API на каждой перерисовке
    fi
fi

# --- Вывод лимитов: «5h <бар> NN% <время до сброса>» ---
if [ -s "$cache" ]; then
    kd=$(cat "$cache" 2>/dev/null)
    k5=$(printf '%s' "$kd" | jq -r '(try ([.limits[]? | select(.window.duration==300 and .window.timeUnit=="TIME_UNIT_MINUTE") | .detail | (.used|tonumber)*100/(.limit|tonumber)] | first) catch empty) // empty' 2>/dev/null)
    kw=$(printf '%s' "$kd" | jq -r '(try (.usage | (.used|tonumber)*100/(.limit|tonumber)) catch empty) // empty' 2>/dev/null)
    r5=$(printf '%s' "$kd" | jq -r '(try ([.limits[]? | select(.window.duration==300 and .window.timeUnit=="TIME_UNIT_MINUTE") | (.detail.resetTime // empty)] | first) catch empty) // empty' 2>/dev/null)
    rw=$(printf '%s' "$kd" | jq -r '(try (.usage.resetTime // empty) catch empty) // empty' 2>/dev/null)

    # kb <процент> <подпись> [resetTime ISO UTC] — бар на 10 сегментов, цвет по порогам
    kb() {
        p=$(printf '%.0f' "$1")
        [ "$p" -gt 100 ] && p=100
        f=$((p / 10)); e=$((10 - f)); b=''
        i=0; while [ $i -lt $f ]; do b="${b}█"; i=$((i + 1)); done
        i=0; while [ $i -lt $e ]; do b="${b}░"; i=$((i + 1)); done
        if [ "$p" -ge 80 ]; then cc=31; elif [ "$p" -ge 50 ]; then cc=33; else cc=32; fi
        printf ' \033[2m│\033[0m \033[36m%s\033[0m \033[%dm%s\033[0m %s%%' "$2" "$cc" "$b" "$p"
        if [ -n "$3" ]; then
            rs=$(date -d "$3" +%s 2>/dev/null)
            if [ -n "$rs" ]; then
                d=$((rs - $(date +%s)))
                [ "$d" -lt 0 ] && d=0
                if [ "$d" -lt 3600 ]; then
                    rst="$((d / 60))м"
                elif [ "$d" -lt 172800 ]; then
                    rst="$((d / 3600))ч"
                else
                    rst="$((d / 86400))д"
                fi
                printf ' \033[2m%s\033[0m' "$rst"
            fi
        fi
    }

    [ -n "$k5" ] && kb "$k5" 5h "$r5"
    [ -n "$kw" ] && kb "$kw" wk "$rw"
fi
