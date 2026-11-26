#!/bin/bash
set -eE

if [ "$(id -u)" -ne 0 ]; then echo "Run as root"; exit 1; fi

# --- Configuration (must match the build parameters) ---
PG_PREFIX="/opt/postgresql-19"
PG_DATA="/var/lib/postgresql/19/data"
PG_USER="postgres"
PG_GROUP="postgres"
PG_LOG="/var/log/postgresql/postgresql-19.log"
LOG_FILE="/var/log/init-start-postgresql-cluster.log"

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

step "1. Creating system user and group"
# Create the group if it does not exist
if ! getent group "${PG_GROUP}" >/dev/null; then
    groupadd "${PG_GROUP}"
    log "OK: group ${PG_GROUP} created"
else
    log "OK: group ${PG_GROUP} already exists"
fi

# Create the user if it does not exist
if ! id -u "${PG_USER}" >/dev/null 2>&1; then
    useradd -m -s /bin/bash -g "${PG_GROUP}" -d "/var/lib/postgresql" "${PG_USER}"
    log "OK: user ${PG_USER} created"
else
    log "OK: user ${PG_USER} already exists"
fi

step "2. Preparing directories"
# Data directory
mkdir -p "${PG_DATA}"
chown -R "${PG_USER}:${PG_GROUP}" "${PG_DATA}"
chmod 700 "${PG_DATA}"

# Log directory
mkdir -p "$(dirname "${PG_LOG}")"
chown -R "${PG_USER}:${PG_GROUP}" "$(dirname "${PG_LOG}")"
log "OK: directories prepared (${PG_DATA}, $(dirname "${PG_LOG}"))"

step "3. Initializing database cluster"
# Verify that the build from download-build-install-postgresql.sh is present
if [ ! -x "${PG_PREFIX}/bin/initdb" ]; then
    log "ERROR: ${PG_PREFIX}/bin/initdb not found, PostgreSQL is not built or installed (run download-build-install-postgresql.sh first)"
    exit 1
fi

# Skip initialization if the cluster is already initialized
if [ ! -f "${PG_DATA}/PG_VERSION" ]; then
    sudo -u "${PG_USER}" "${PG_PREFIX}/bin/initdb" -D "${PG_DATA}" -E UTF8 --locale=C --auth-local=peer --auth-host=scram-sha-256
    log "OK: new cluster initialized in ${PG_DATA}"
else
    log "OK: cluster already initialized (${PG_DATA}/PG_VERSION found), initdb skipped"
fi

step "4. Configuring environment variables"
# Create a profile script for convenient shell usage
cat > /etc/profile.d/postgresql-19.sh <<EOF
export PATH="${PG_PREFIX}/bin:\$PATH"
export PGDATA="${PG_DATA}"
export MANPATH="${PG_PREFIX}/share/man:\$MANPATH"
EOF
chmod +x /etc/profile.d/postgresql-19.sh
log "OK: /etc/profile.d/postgresql-19.sh created"

step "5. Creating systemd service"
# On Debian the path for systemd unit files is /lib/systemd/system/
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
log "OK: /lib/systemd/system/postgresql-19.service created"

step "6. Starting service and enabling autostart"
systemctl daemon-reload
systemctl enable postgresql-19.service
systemctl start postgresql-19.service

# Verify that the service actually started.
if systemctl is-active --quiet postgresql-19.service; then
    log "OK: service postgresql-19.service is active"
else
    log "ERROR: service postgresql-19.service is not active, check: journalctl -u postgresql-19.service"
    exit 1
fi

log "=== Done ==="
log "PostgreSQL 19 cluster is up and running"
log "Service status: systemctl status postgresql-19.service"
log "Database log: ${PG_LOG}"
log "Connect: sudo -u ${PG_USER} ${PG_PREFIX}/bin/psql"
log "Full log saved to ${LOG_FILE}"