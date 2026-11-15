
#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://kekeridze41-boop.github.io/connect_new"
KEY_URL="$REPO_URL/connect-archive-keyring.gpg"
KEY_FILE="/etc/apt/keyrings/connect.gpg"
SOURCE_FILE="/etc/apt/sources.list.d/connect.list"

if [[ $EUID -eq 0 ]]; then
    echo "Запускайте установщик от обычного пользователя, без sudo."
    exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
    echo "Ошибка: требуется Ubuntu или Debian с APT."
    exit 1
fi

echo "=== Установка Connect ==="

sudo -v

sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

sudo install -d -m 755 /etc/apt/keyrings

TMP_KEY="$(mktemp)"
trap 'rm -f "$TMP_KEY"' EXIT

echo "Загрузка публичного ключа Connect..."
curl --fail --silent --show-error --location \
    "$KEY_URL" -o "$TMP_KEY"

EXPECTED_FINGERPRINT="66771FD954E161BC722DAC0979910FAC64F71C63"

ACTUAL_FINGERPRINT="$(
    gpg --batch --show-keys --with-colons "$TMP_KEY" |
    awk -F: '$1 == "fpr" { print $10; exit }'
)"

if [[ "$ACTUAL_FINGERPRINT" != "$EXPECTED_FINGERPRINT" ]]; then
    echo "Ошибка: отпечаток GPG-ключа не совпадает."
    exit 1
fi

sudo install -m 644 "$TMP_KEY" "$KEY_FILE"

ARCH="$(dpkg --print-architecture)"

echo "Подключение APT-репозитория..."

printf 'deb [arch=%s signed-by=%s] %s ./\n' \
    "$ARCH" "$KEY_FILE" "$REPO_URL/" |
    sudo tee "$SOURCE_FILE" >/dev/null

sudo apt-get update
sudo apt-get install -y connect

echo
echo "=== Connect установлен ==="

CONFIG_FILE="$HOME/.config/connect/credentials.conf"

if [[ -f "$CONFIG_FILE" ]]; then
    echo "Существующая конфигурация сохранена."
else
    echo "Теперь необходимо ввести учётные данные."
    /usr/bin/connect --setup
fi

echo
echo "Установка завершена."
echo "Пример: connect 1.1.23.229 1/1/16:11"
