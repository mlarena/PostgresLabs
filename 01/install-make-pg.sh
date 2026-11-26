#!/bin/bash
set -e

# --- Переменные (должны совпадать с параметрами сборки) ---
PG_PREFIX="/opt/postgresql-19"
PG_DATA="/var/lib/postgresql/19/data"
PG_USER="postgres"
PG_GROUP="postgres"
PG_LOG="/var/log/postgresql/postgresql-19.log"

echo "=== 1. Создание системного пользователя и группы ==="
# Создаём группу, если её нет
if ! getent group "${PG_GROUP}" >/dev/null; then
    groupadd "${PG_GROUP}"
fi

# Создаём пользователя, если его нет
if ! id -u "${PG_USER}" >/dev/null 2>&1; then
    useradd -m -s /bin/bash -g "${PG_GROUP}" -d "/var/lib/postgresql" "${PG_USER}"
    echo "Пользователь ${PG_USER} создан."
else
    echo "Пользователь ${PG_USER} уже существует."
fi

echo "=== 2. Подготовка каталогов ==="
# Каталог для данных
mkdir -p "${PG_DATA}"
chown -R "${PG_USER}:${PG_GROUP}" "${PG_DATA}"
chmod 700 "${PG_DATA}"

# Каталог для логов
mkdir -p "$(dirname "${PG_LOG}")"
chown -R "${PG_USER}:${PG_GROUP}" "$(dirname "${PG_LOG}")"

echo "=== 3. Инициализация кластера баз данных ==="
# Проверяем, не инициализирован ли уже кластер
if [ ! -f "${PG_DATA}/PG_VERSION" ]; then
    echo "Инициализация нового кластера в ${PG_DATA}..."
    sudo -u "${PG_USER}" "${PG_PREFIX}/bin/initdb" -D "${PG_DATA}" -E UTF8 --locale=C
else
    echo "Кластер уже инициализирован (найден ${PG_DATA}/PG_VERSION). Пропускаем initdb."
fi

echo "=== 4. Настройка переменных окружения ==="
# Создаём profile-скрипт для удобства работы в shell
cat > /etc/profile.d/postgresql-19.sh <<EOF
export PATH="${PG_PREFIX}/bin:\$PATH"
export PGDATA="${PG_DATA}"
export MANPATH="${PG_PREFIX}/share/man:\$MANPATH"
EOF
chmod +x /etc/profile.d/postgresql-19.sh

echo "=== 5. Создание systemd-сервиса ==="
# Для Debian путь к systemd unit-файлам — /lib/systemd/system/
cat > /lib/systemd/system/postgresql-19.service <<EOF
[Unit]
Description=PostgreSQL 19 database server (custom build)
Documentation=man:postgres(1)
After=network.target

[Service]
Type=notify
User=${PG_USER}
Group=${PG_GROUP}
ExecStart=${PG_PREFIX}/bin/postgres -D ${PG_DATA}
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=mixed
KillSignal=SIGINT
TimeoutSec=0
Restart=on-failure
RestartSec=5
StandardOutput=append:${PG_LOG}
StandardError=append:${PG_LOG}

[Install]
WantedBy=multi-user.target
EOF

echo "=== 6. Запуск и включение автозапуска ==="
systemctl daemon-reload
systemctl enable postgresql-19.service
systemctl start postgresql-19.service

echo "=== Готово! ==="
echo "PostgreSQL 19 запущен."
echo "Статус: systemctl status postgresql-19.service"
echo "Лог:    tail -f ${PG_LOG}"
echo "Вход:   sudo -u ${PG_USER} ${PG_PREFIX}/bin/psql"