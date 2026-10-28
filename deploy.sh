#!/usr/bin/env bash
# =============================================================================
# deploy.sh - Pull code from Git, then deploy the SELECTED applications:
#               admin  -> React bundle served by Nginx
#               ui     -> React bundle served by Nginx
#               api    -> Spring Boot (or any) JAR run as a systemd service
#
# Usage:
#   sudo ./deploy.sh                 # interactive menu (when run from a terminal)
#   sudo ./deploy.sh admin           # deploy only admin
#   sudo ./deploy.sh admin ui        # deploy admin and ui
#   sudo ./deploy.sh api             # deploy only the backend JAR
#   sudo ./deploy.sh all             # deploy everything
#   ./deploy.sh --help
#
# Without arguments and without a terminal (cron/CI), everything is deployed.
# Tested on: Ubuntu/Debian (apt) and CentOS/RHEL/Rocky (yum/dnf)
# =============================================================================
set -Eeuo pipefail

# ----------------------------- CONFIGURATION ---------------------------------
REPO_URL="https://github.com/QuocViet22/trac-dia-thien-phu-deployment.git"   # <-- change me
BRANCH="master"
SRC_DIR="/opt/deploy/source"            # where the repo is cloned

# Folder names INSIDE the repo
REACT_APP1_SRC="admin"
REACT_APP2_SRC="ui"
JAR_FILE_NAME=""                        # leave empty to auto-detect first *.jar in repo root

# Nginx targets
APP1_WEB_ROOT="/var/www/admin"
APP2_WEB_ROOT="/var/www/ui"
APP1_PORT="80"                          # nginx port for app1
APP2_PORT="80"                          # same port as app1: nginx routes by server_name
APP1_SERVER_NAME="tracdiathienphuadmin.viethq.tech"
APP2_SERVER_NAME="tracdiathienphu.viethq.tech"

# Backend service
SERVICE_NAME="api"
APP_DIR="/opt/${SERVICE_NAME}"
SERVICE_USER="api"
JAVA_VERSION_REQUIRED=21               # Spring Boot app needs Java 21
JAVA_OPTS="-Xms256m -Xmx512m"
APP_PORT="8080"                         # port the JAR listens on (used for /api proxy + health check)
API_SERVER_NAME="api.viethq.tech"       # domain that reverse-proxies to the JAR
API_LISTEN_PORT="80"                    # nginx port for the API domain
MAX_BODY_SIZE="50m"                     # max upload size through the proxy

# Nginx config handling. Domains already have HTTPS, so an existing config is kept
# as-is (the script will NOT overwrite your SSL settings). Set to "yes" only if you
# want the script to regenerate the config from the template below.
REWRITE_NGINX_CONF="no"

# Git auth (optional): for private repos use an SSH URL with a deploy key,
# or a URL like https://<token>@github.com/org/repo.git
# -----------------------------------------------------------------------------

log()  { echo -e "\n\033[1;34m[$(date +%H:%M:%S)] $*\033[0m"; }
ok()   { echo -e "\033[1;32m  ✔ $*\033[0m"; }
die()  { echo -e "\033[1;31m  ✘ $*\033[0m" >&2; exit 1; }

# ----------------------------- APP SELECTION ---------------------------------
DEPLOY_ADMIN=0
DEPLOY_UI=0
DEPLOY_API=0

usage() {
  cat <<EOF
Usage: sudo $0 [app ...]

Apps:
  admin    React admin bundle  (${APP1_SERVER_NAME})
  ui       React UI bundle     (${APP2_SERVER_NAME})
  api      Backend JAR service (${API_SERVER_NAME})
  all      Everything above

Options:
  -h, --help   Show this help

With no arguments, an interactive menu is shown (if run from a terminal);
otherwise everything is deployed.
EOF
}

select_app() {
  case "$1" in
    1|admin)                  DEPLOY_ADMIN=1 ;;
    2|ui)                     DEPLOY_UI=1 ;;
    3|api|backend|jar)        DEPLOY_API=1 ;;
    4|all|a)                  DEPLOY_ADMIN=1; DEPLOY_UI=1; DEPLOY_API=1 ;;
    *) die "Unknown application: '$1' (valid: admin, ui, api, all)" ;;
  esac
}

select_interactive() {
  echo "Select the applications to deploy:"
  echo "  1) admin  - React admin   (${APP1_SERVER_NAME})"
  echo "  2) ui     - React UI      (${APP2_SERVER_NAME})"
  echo "  3) api    - Backend JAR   (${API_SERVER_NAME})"
  echo "  4) all"
  local reply tok
  read -r -p "Enter one or more numbers/names (e.g. '1 3' or 'admin,api'): " reply </dev/tty
  reply="${reply//,/ }"
  [[ -n "${reply// /}" ]] || die "Nothing selected - aborting."
  for tok in $reply; do select_app "$tok"; done
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
esac

if [[ $# -gt 0 ]]; then
  for arg in "$@"; do select_app "$arg"; done
elif [[ -t 0 && -t 1 ]]; then
  select_interactive
else
  echo "No application specified and no terminal available - deploying all."
  select_app all
fi

NEED_FRONTEND=0
if [[ "$DEPLOY_ADMIN" -eq 1 || "$DEPLOY_UI" -eq 1 ]]; then NEED_FRONTEND=1; fi

SELECTED=""
[[ "$DEPLOY_ADMIN" -eq 1 ]] && SELECTED+="admin "
[[ "$DEPLOY_UI"    -eq 1 ]] && SELECTED+="ui "
[[ "$DEPLOY_API"   -eq 1 ]] && SELECTED+="api "

# ----------------------------- ERROR HANDLING --------------------------------
API_STOPPED=0
on_error() {
  local line="$1"
  echo -e "\033[1;31m  ✘ Failed at line ${line}.\033[0m" >&2
  if [[ "$API_STOPPED" -eq 1 ]]; then
    echo -e "\033[1;33m  ! Backend was stopped - trying to bring it back up...\033[0m" >&2
    if [[ -f "/etc/systemd/system/${SERVICE_NAME}.service" ]]; then
      systemctl start "$SERVICE_NAME" 2>/dev/null || true
    fi
  fi
  exit 1
}
trap 'on_error $LINENO' ERR

[[ $EUID -eq 0 ]] || die "Please run as root (sudo ./deploy.sh)"

log "Selected applications: ${SELECTED}"

# ------------------------- STEP 0: prerequisites -----------------------------
log "STEP 0: Checking prerequisites"
install_pkgs() {
  if command -v apt-get >/dev/null; then
    apt-get update -y
    apt-get install -y "$@"
  elif command -v dnf >/dev/null; then
    dnf install -y "$@"
  elif command -v yum >/dev/null; then
    yum install -y "$@"
  else
    die "No supported package manager found"
  fi
}

command -v git   >/dev/null || install_pkgs git
command -v nginx >/dev/null || install_pkgs nginx

# Find a java binary with major version >= JAVA_VERSION_REQUIRED (prints path, or nothing)
find_java() {
  local c v
  for c in "$(command -v java 2>/dev/null || true)" /usr/lib/jvm/*/bin/java; do
    [[ -x "$c" ]] || continue
    v="$("$c" -version 2>&1 | awk -F'"' '/version/ {print $2}' | cut -d. -f1)"
    [[ "$v" =~ ^[0-9]+$ ]] && (( v >= JAVA_VERSION_REQUIRED )) && { echo "$c"; return 0; }
  done
  return 1
}

JAVA_BIN=""
if [[ "$DEPLOY_API" -eq 1 ]]; then
  JAVA_BIN="$(find_java || true)"
  if [[ -z "$JAVA_BIN" ]]; then
    log "Java ${JAVA_VERSION_REQUIRED}+ not found - installing"
    if command -v apt-get >/dev/null; then install_pkgs "openjdk-${JAVA_VERSION_REQUIRED}-jre-headless"
    else install_pkgs "java-${JAVA_VERSION_REQUIRED}-openjdk-headless"; fi
    JAVA_BIN="$(find_java || true)"
    [[ -n "$JAVA_BIN" ]] || die "Could not install Java ${JAVA_VERSION_REQUIRED}. Install it manually (e.g. Temurin) and re-run."
  fi
  ok "Using Java: $JAVA_BIN ($("$JAVA_BIN" -version 2>&1 | head -n1))"
fi
ok "Prerequisites are available"

# ------------------------- STEP 1: pull source code --------------------------
log "STEP 1: Pulling source code from ${REPO_URL} (${BRANCH})"
mkdir -p "$(dirname "$SRC_DIR")"
if [[ -d "$SRC_DIR/.git" ]]; then
  git -C "$SRC_DIR" fetch --all --prune
  git -C "$SRC_DIR" checkout "$BRANCH"
  git -C "$SRC_DIR" reset --hard "origin/${BRANCH}"
else
  rm -rf "$SRC_DIR"
  git clone --branch "$BRANCH" "$REPO_URL" "$SRC_DIR"
fi
ok "Source at commit $(git -C "$SRC_DIR" rev-parse --short HEAD)"

# Validate only what was selected
if [[ "$DEPLOY_ADMIN" -eq 1 ]]; then
  [[ -d "$SRC_DIR/$REACT_APP1_SRC" ]] || die "Folder not found: $SRC_DIR/$REACT_APP1_SRC"
fi
if [[ "$DEPLOY_UI" -eq 1 ]]; then
  [[ -d "$SRC_DIR/$REACT_APP2_SRC" ]] || die "Folder not found: $SRC_DIR/$REACT_APP2_SRC"
fi
if [[ "$DEPLOY_API" -eq 1 ]]; then
  if [[ -z "$JAR_FILE_NAME" ]]; then
    JAR_PATH="$(find "$SRC_DIR" -maxdepth 1 -name '*.jar' | head -n1)"
  else
    JAR_PATH="$SRC_DIR/$JAR_FILE_NAME"
  fi
  [[ -f "${JAR_PATH:-}" ]] || die "JAR file not found in $SRC_DIR"
  ok "Found JAR: $(basename "$JAR_PATH")"
fi

# ------------------------- STEP 1b: stop the backend (if selected) -----------
# Only the backend is stopped. Nginx keeps running, so applications you did not
# select stay online (static files are replaced in place by rsync).
if [[ "$DEPLOY_API" -eq 1 ]]; then
  log "STEP 1b: Stopping backend service before updating"
  if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    systemctl stop "$SERVICE_NAME"
    ok "Stopped backend service '${SERVICE_NAME}'"
  else
    ok "Backend service '${SERVICE_NAME}' was not running"
  fi
  API_STOPPED=1
fi

# ------------------------- STEP 2: deploy React to Nginx ---------------------
deploy_react() {
  local src="$1" dest="$2"
  mkdir -p "$dest"
  # rsync keeps it atomic-ish & removes stale files; fall back to cp
  if command -v rsync >/dev/null; then
    rsync -a --delete "$src"/ "$dest"/
  else
    rm -rf "${dest:?}"/*
    cp -a "$src"/. "$dest"/
  fi
  chown -R www-data:www-data "$dest" 2>/dev/null || chown -R nginx:nginx "$dest" 2>/dev/null || true
  find "$dest" -type d -exec chmod 755 {} \;
  find "$dest" -type f -exec chmod 644 {} \;
}

if [[ "$NEED_FRONTEND" -eq 1 ]]; then
  log "STEP 2: Deploying React bundles to web roots"
  if [[ "$DEPLOY_ADMIN" -eq 1 ]]; then
    deploy_react "$SRC_DIR/$REACT_APP1_SRC" "$APP1_WEB_ROOT"
    ok "admin -> $APP1_WEB_ROOT"
  fi
  if [[ "$DEPLOY_UI" -eq 1 ]]; then
    deploy_react "$SRC_DIR/$REACT_APP2_SRC" "$APP2_WEB_ROOT"
    ok "ui    -> $APP2_WEB_ROOT"
  fi
fi

# ------------------------- STEP 2b: Nginx config -----------------------------
# Needed when any frontend is deployed, or when the API is deployed and no
# config exists yet (the config also contains the API reverse proxy).
log "STEP 2b: Nginx config"
NGINX_CONF_NAME="${SERVICE_NAME}-react.conf"
if [[ -d /etc/nginx/sites-available ]]; then
  NGINX_CONF="/etc/nginx/sites-available/${NGINX_CONF_NAME}"
else
  NGINX_CONF="/etc/nginx/conf.d/${NGINX_CONF_NAME}"
fi

if [[ -f "$NGINX_CONF" && "$REWRITE_NGINX_CONF" != "yes" ]]; then
  ok "Keeping existing Nginx config: $NGINX_CONF (REWRITE_NGINX_CONF=no)"
else
cat > "$NGINX_CONF" <<EOF
# Generated by deploy.sh - do not edit manually
server {
    listen ${APP1_PORT};
    server_name ${APP1_SERVER_NAME};
    root ${APP1_WEB_ROOT};
    index index.html;

    location / {
        try_files \$uri /index.html;   # React Router support
    }
    location ~* \.(js|css|png|jpg|jpeg|gif|svg|ico|woff2?)\$ {
        expires 7d;
        add_header Cache-Control "public";
    }
}

server {
    listen ${APP2_PORT};
    server_name ${APP2_SERVER_NAME};
    root ${APP2_WEB_ROOT};
    index index.html;

    location / {
        try_files \$uri /index.html;
    }
    location ~* \.(js|css|png|jpg|jpeg|gif|svg|ico|woff2?)\$ {
        expires 7d;
        add_header Cache-Control "public";
    }
}

# Reverse proxy for the backend API (JAR service)
server {
    listen ${API_LISTEN_PORT};
    server_name ${API_SERVER_NAME};

    client_max_body_size ${MAX_BODY_SIZE};

    location / {
        proxy_pass http://127.0.0.1:${APP_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_connect_timeout 30s;
        proxy_read_timeout 120s;
        proxy_send_timeout 120s;
    }
}
EOF
ok "Nginx config written: $NGINX_CONF"
fi

if [[ -d /etc/nginx/sites-enabled ]]; then
  ln -sf "$NGINX_CONF" "/etc/nginx/sites-enabled/${NGINX_CONF_NAME}"
  rm -f /etc/nginx/sites-enabled/default   # avoid clash on port 80
fi

nginx -t
systemctl enable nginx >/dev/null 2>&1 || true
if systemctl is-active --quiet nginx; then
  systemctl reload nginx
  ok "Nginx reloaded"
else
  systemctl start nginx
  ok "Nginx started"
fi

# ------------------------- STEP 3: JAR as a systemd service ------------------
if [[ "$DEPLOY_API" -eq 1 ]]; then
  log "STEP 3: Deploying JAR as service '${SERVICE_NAME}'"
  id "$SERVICE_USER" >/dev/null 2>&1 || \
    useradd --system --no-create-home --shell /usr/sbin/nologin "$SERVICE_USER"

  mkdir -p "$APP_DIR"
  # keep one backup of the previous jar
  if [[ -f "$APP_DIR/app.jar" ]]; then cp -f "$APP_DIR/app.jar" "$APP_DIR/app.jar.bak"; fi
  cp -f "$JAR_PATH" "$APP_DIR/app.jar"
  chown -R "$SERVICE_USER":"$SERVICE_USER" "$APP_DIR"
  chmod 500 "$APP_DIR/app.jar"

  cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=${SERVICE_NAME} backend service
After=network.target

[Service]
Type=simple
User=${SERVICE_USER}
WorkingDirectory=${APP_DIR}
ExecStart=${JAVA_BIN} ${JAVA_OPTS} -jar ${APP_DIR}/app.jar --spring.profiles.active=prod --server.port=${APP_PORT}
SuccessExitStatus=143
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable "$SERVICE_NAME" >/dev/null 2>&1
  systemctl restart "$SERVICE_NAME"
  ok "Service restarted"
  API_STOPPED=0
fi

# ------------------------- STEP 4: verify ------------------------------------
log "STEP 4: Verifying deployment"
if [[ "$DEPLOY_API" -eq 1 ]]; then
  sleep 5
  if systemctl is-active --quiet "$SERVICE_NAME"; then
    ok "Service '${SERVICE_NAME}' is running"
  else
    journalctl -u "$SERVICE_NAME" -n 30 --no-pager
    die "Service failed to start"
  fi
fi

check_site() {
  local name="$1" port="$2" okcodes="$3"
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' -H "Host: ${name}" "http://127.0.0.1:${port}/" || true)"
  if [[ "$code" =~ ^(${okcodes})$ ]]; then
    ok "${name} -> HTTP $code"
  else
    echo "  ! ${name} -> HTTP $code"
  fi
}
# 301/302 are expected when HTTP -> HTTPS redirect is on
if [[ "$DEPLOY_ADMIN" -eq 1 ]]; then check_site "$APP1_SERVER_NAME" "$APP1_PORT" "200|301|302"; fi
if [[ "$DEPLOY_UI"    -eq 1 ]]; then check_site "$APP2_SERVER_NAME" "$APP2_PORT" "200|301|302"; fi
if [[ "$DEPLOY_API"   -eq 1 ]]; then check_site "$API_SERVER_NAME"  "$API_LISTEN_PORT" "[234][0-9][0-9]"; fi

log "DONE 🎉  Deployed: ${SELECTED}| Commit: $(git -C "$SRC_DIR" rev-parse --short HEAD)"
if [[ "$DEPLOY_API" -eq 1 ]]; then
  echo "  Logs:    journalctl -u ${SERVICE_NAME} -f"
  echo "  Status:  systemctl status ${SERVICE_NAME}"
fi