#!/usr/bin/env bash
# Подставляет значения вместо __NAME__ и т.п. Использование: render.sh <шаблон> KEY=VALUE ...
# Выводит результат в stdout. Значения не должны содержать символ "|".
set -euo pipefail
tpl=${1:?шаблон}; shift
args=()
for kv in "$@"; do
  args+=(-e "s|__${kv%%=*}__|${kv#*=}|g")
done
sed "${args[@]}" "$tpl"
