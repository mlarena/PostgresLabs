#!/bin/bash
set -e  # Останавливать скрипт при любой ошибке

# --- Переменные ---
PG_VERSION="19rc2"
PG_PREFIX="/opt/postgresql-19"
SRC_DIR="/tmp/postgresql-build"
TARBALL="postgresql-${PG_VERSION}.tar.gz"
DOWNLOAD_URL="https://ftp.postgresql.org/pub/source/v${PG_VERSION}/${TARBALL}"

echo "=== 1. Установка зависимостей ==="
# Базовые инструменты для сборки
apt update
apt install -y build-essential libreadline-dev zlib1g-dev curl sudo  bison flex

# Дополнительные зависимости, которые обычно нужны для "полной" сборки,
# аналогичной стандартному пакету Debian (согласно build-depends [citation:1])
# Если какая-то из них не нужна, ее можно убрать, но для make world
# лучше иметь большинство.
apt install -y \
    libicu-dev \
    libssl-dev \
    libxml2-dev \
    libxslt1-dev \
    libldap2-dev \
    libkrb5-dev \
    libpam0g-dev \
    libsystemd-dev \
    libselinux1-dev \
    liblz4-dev \
    libzstd-dev \
    llvm-dev \
    clang \
          --without-perl \
            --without-python \
            --without-tcl
    pkg-config

echo "=== 2. Загрузка и распаковка исходников ==="
mkdir -p "${SRC_DIR}"
cd "${SRC_DIR}"

if [ ! -f "${TARBALL}" ]; then
    curl -LO "${DOWNLOAD_URL}"
fi

# Удаляем старую распакованную директорию, если есть
rm -rf "postgresql-${PG_VERSION}"
tar -xzf "${TARBALL}"
cd "postgresql-${PG_VERSION}"

echo "=== 3. Конфигурация ==="
# Используем --prefix=/opt/postgresql-19.
# Для сборки "полной" версии (как в Debian) включаем основные опции.
# Обратите внимание: --with-llvm может потребовать значительного времени и памяти.
./configure \
    --prefix="${PG_PREFIX}" \
    --with-icu \
    --with-openssl \
    --with-libxml \
    --with-libxslt \
    --with-ldap \
    --with-gssapi \
    --with-pam \
    --with-systemd \
    --with-selinux \
    --with-lz4 \
    --with-zstd \
    --with-llvm \
  --without-perl \
            --without-python \
            --without-tcl

echo "=== 4. Сборка (make world) ==="
# 'make world' собирает сервер, contrib и документацию [citation:8]
# Для ускорения можно использовать -j$(nproc), но это может потребовать много RAM.
make world

echo "=== 5. Установка ==="
# 'make install-world' устанавливает всё, что было собрано 'make world'
sudo make install-world

echo "=== Готово! ==="
echo "PostgreSQL ${PG_VERSION} установлен в ${PG_PREFIX}"
echo "Бинарные файлы находятся в ${PG_PREFIX}/bin"
echo "Для инициализации базы данных выполните:"
echo "  sudo adduser postgres  # если пользователя еще нет"
echo "  sudo mkdir -p /var/lib/postgresql/data"
echo "  sudo chown postgres:postgres /var/lib/postgresql/data"
echo "  sudo -u postgres ${PG_PREFIX}/bin/initdb -D /var/lib/postgresql/data"