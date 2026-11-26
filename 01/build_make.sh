#!/bin/bash
set -e  # Останавливать скрипт при любой ошибке

# --- Переменные ---
PG_VERSION="19rc2"
PG_PREFIX="/opt/postgresql-19"
SRC_DIR="/tmp/postgresql-build"
TARBALL="postgresql-${PG_VERSION}.tar.gz"
DOWNLOAD_URL="https://ftp.postgresql.org/pub/source/v${PG_VERSION}/${TARBALL}"

echo "=== 1. Установка зависимостей ==="
apt update
apt install -y build-essential libreadline-dev zlib1g-dev curl sudo bison flex tree

# Дополнительные зависимости для расширенной сборки.
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
# Флаги --without-* относятся только к configure и убирают PL/Perl, PL/Python, PL/Tcl.
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

echo "=== 4. Сборка ==="
# 'make world' собирает сервер, contrib и документацию.
# Для ускорения используется -j$(nproc), но это может потребовать много RAM.
make world -j"$(nproc)"

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