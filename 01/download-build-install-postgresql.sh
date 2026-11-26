#!/bin/bash
set -eE

if [ "$(id -u)" -ne 0 ]; then echo "Run as root"; exit 1; fi

# --- Configuration ---
PG_VERSION="19rc2"
PG_PREFIX="/opt/postgresql-19"
SRC_DIR="/psg_build"
TARBALL="postgresql-${PG_VERSION}.tar.gz"
DOWNLOAD_URL="https://ftp.postgresql.org/pub/source/v${PG_VERSION}/${TARBALL}"
LOG_FILE="/var/log/download-build-install-postgresql.log"

# --- Logging setup ---
# All command output is written to the log file;
# only status messages and errors are shown on the screen.
mkdir -p "$(dirname "${LOG_FILE}")"
exec 3>&1
exec >>"${LOG_FILE}" 2>&1

# Write a status message to the screen and to the log file.
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "${msg}"
    echo "${msg}" >&3
}

# Mark the beginning of a step.
step() {
    CURRENT_STEP="$*"
    log "=== ${CURRENT_STEP} ==="
}

# Error handler: report the failed step on screen and in the log file.
on_error() {
    local rc=$?
    local last_lines
    last_lines="$(tail -n 30 "${LOG_FILE}")"
    log "ERROR: step '${CURRENT_STEP}' failed at line $1 (exit code ${rc})"
    echo "---- last output lines ----" >&3
    echo "${last_lines}" >&3
    echo "---- end of output ----" >&3
    log "ERROR: full log: ${LOG_FILE}"
    exit "${rc}"
}
CURRENT_STEP="startup"
trap 'on_error ${LINENO}' ERR

step "1. Installing build dependencies"
apt update
apt install -y build-essential libreadline-dev zlib1g-dev curl sudo bison flex tree

# Extra dependencies for the extended build.
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
    pkg-config \
    libxml2-utils \
    docbook-xml \
    docbook-xsl \
    xsltproc
log "OK: build dependencies installed"

step "2. Downloading and extracting source code"
mkdir -p "${SRC_DIR}"
cd "${SRC_DIR}"

if [ ! -f "${TARBALL}" ]; then
    curl -LO "${DOWNLOAD_URL}"
fi

# Remove the previously extracted source tree, if any.
rm -rf "postgresql-${PG_VERSION}"
tar -xzf "${TARBALL}"
cd "postgresql-${PG_VERSION}"
log "OK: source code extracted to ${SRC_DIR}/postgresql-${PG_VERSION}"

step "3. Configuring build"
# The --without-* options apply to configure only and disable PL/Perl, PL/Python, PL/Tcl.
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
log "OK: build configured with prefix ${PG_PREFIX}"

step "4. Building with make world (this may take a while)"
# 'make world' builds the server, contrib and the documentation.
# -j$(nproc) speeds the build up, but may require a lot of RAM.
make world -j"$(nproc)"
log "OK: build completed"

step "5. Installing"
# 'make install-world' installs everything built by 'make world'.
sudo make install-world

# Verify that the installation is complete.
if [ ! -x "${PG_PREFIX}/bin/initdb" ]; then
    log "ERROR: ${PG_PREFIX}/bin/initdb not found, installation is incomplete"
    exit 1
fi
log "OK: PostgreSQL ${PG_VERSION} installed to ${PG_PREFIX}"

log "=== Done ==="
log "Binaries are located in ${PG_PREFIX}/bin"
log "Next step: run init-start-postgresql-cluster.sh to initialize and start the database cluster"
log "Full log saved to ${LOG_FILE}"