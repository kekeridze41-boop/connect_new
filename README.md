## Установка Connect

Connect — утилита для подключения к сетевому оборудованию и диагностики ONU.

**Требования:** Ubuntu или Debian с доступом в интернет, `sudo`.

### Первоначальная установка

В терминале выполните:

```bash
curl -fsSL https://kekeridze41-boop.github.io/connect_new/install.sh | bash
```

Установщик автоматически подключит APT-репозиторий, установит Connect и предложит ввести учётные данные.

### Использование

```bash
connect IP PORT
```

Пример:

```bash
connect 1.1.23.229 1/1/16:11
```

### Обновление

```bash
sudo apt update && sudo apt upgrade
```

### Изменение учётных данных

```bash
connect --setup
```

Учётные данные хранятся локально в `~/.config/connect/credentials.conf` с правами доступа `600` и не перезаписываются при обновлениях.
