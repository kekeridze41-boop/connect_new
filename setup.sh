
#!/usr/bin/env bash

set -euo pipefail

CONFIG_DIR="$HOME/.config/connect"
CONFIG_FILE="$CONFIG_DIR/credentials.conf"

echo "=== Первоначальная настройка Connect ==="
echo

read -r -p "Личный логин: " PERSONAL_USER
read -r -s -p "Личный пароль: " PERSONAL_PASSWORD
echo

read -r -p "Логин администратора: " ADMIN_USER
read -r -s -p "Пароль администратора: " ADMIN_PASSWORD
echo

read -r -s -p "Пароль администратора для 1.1.23.244: " SPECIAL_PASSWORD
echo

if [[ -f "$CONFIG_FILE" ]]; then
    read -r -p "Конфигурация уже существует. Перезаписать? [y/N]: " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "Настройка отменена."
        exit 0
    fi
fi

mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"

umask 077

export CONFIG_FILE PERSONAL_USER PERSONAL_PASSWORD
export ADMIN_USER ADMIN_PASSWORD SPECIAL_PASSWORD

python3 - <<'PY'
import os

def tcl_string(value):
    return '"' + ''.join(
        f'\\u{ord(char):04x}' if ord(char) <= 0xffff
        else f'\\U{ord(char):08x}'
        for char in value
    ) + '"'

fields = {
    "PersonalUser": "PERSONAL_USER",
    "PersonalPassword": "PERSONAL_PASSWORD",
    "AdminUser": "ADMIN_USER",
    "AdminPassword": "ADMIN_PASSWORD",
    "SpecialPassword": "SPECIAL_PASSWORD",
}

config_file = os.environ["CONFIG_FILE"]

with open(config_file, "w", encoding="utf-8") as file:
    for key, env_name in fields.items():
        file.write(f"set {key} {tcl_string(os.environ[env_name])}\n")
PY

chmod 600 "$CONFIG_FILE"

echo
echo "Учётные данные сохранены в $CONFIG_FILE"
echo "Настройка завершена."
