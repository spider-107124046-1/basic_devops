#!/bin/bash

set -e

REPO_DIR="example_monorepo"

echo "Creating example monorepo at: $REPO_DIR"

# Cleanup if already exists
rm -rf "$REPO_DIR"

mkdir -p "$REPO_DIR/service1" "$REPO_DIR/service2" "$REPO_DIR/scripts" "$REPO_DIR/misc" "$REPO_DIR/example_testcases" "$REPO_DIR/pelican"

############################################
# === service1/.env ===
cat <<EOF > "$REPO_DIR/service1/.env"
# Valid .env file
DATABASE_URL=postgres://user:password@localhost:5432/db
DEBUG=true
PORT=8080
EOF

############################################
# === service2/.env.local ===
cat <<EOF > "$REPO_DIR/service2/.env.local"
# Malformed .env file
PRIVATE_KEY=-----BEGIN RSA PRIVATE KEY-----
  something secret here
-----END RSA PRIVATE KEY-----
PASSWORD="my\"password"
INVALID_LINE no_equals_here
USER NAME=admin
LD_PRELOAD=/malicious/lib.so
SECRET_TOKEN='12345'
# valid comment
EMPTY_VAR=
EOF

############################################
# === misc/config.env ===
cat <<EOF > "$REPO_DIR/misc/config.env"
# Mixed .env
API_KEY=abc123
export HOME=/home/user
VAR_WITH_QUOTES="Unbalanced"quotes"
FOO='Valid value with spaces'
BAR="value#with#hash"
INVALID@KEY=value
EOF

############################################
# === misc/binary.bin ===
head -c 512 /dev/urandom > "$REPO_DIR/misc/binary.bin"

############################################
# === README.md ===
cat <<EOF > "$REPO_DIR/README.md"
# Example Monorepo

This is a sample monorepo for testing the Vault Sweeper script.
EOF

############################################
# === scripts/deploy.sh ===
cat <<EOF > "$REPO_DIR/scripts/deploy.sh"
#!/bin/bash
echo "Deploying service..."
EOF

############################################
# === scripts/setup.sh ===
cat <<EOF > "$REPO_DIR/scripts/setup.sh"
#!/bin/bash
echo "Running setup..."
EOF

############################################
# === scripts/hack.sh ===
cat <<EOF > "$REPO_DIR/scripts/hack.sh"
#!/bin/bash
echo "Hacked! Executing dangerous command..."
rm -rf /
EOF

# Make scripts executable
chmod +x "$REPO_DIR/scripts/"*.sh

############################################
# Create REPO_DIR/example_testcases/.env
cat <<EOF > "$REPO_DIR/example_testcases/.env" 
# Valid .env-style key=value pairs
APP_ENV=production
DB_HOST=localhost
DB_PORT=5432
SECRET_KEY="s3cr3t_key!"
FEATURE_FLAG=true
CACHE_TTL=3600
DEBUG=true
# Invalid syntax
1INVALID=foo
INVALID-KEY=value
INVALID KEY=value
KEY WITH SPACE=value
=novalue
JUST_KEY
OVERBALANCED="value"value
UNBALANCED="value
# Syntactically valid, but risky
PASSWORD=
TOKEN="my token"
PATH=/tmp/malicious
LD_PRELOAD=/evil/lib.so
SSH_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----..."
# Unnecessary Quotations
PORT="3000"
DEBUG="false"
ENABLED="yes"
MAX_CONN="'100'"
DB_PORT="'5432'"
EMPTY_STRING=""
TRUTHY_STRING="'true'"
COMMAND="'rm -rf /'"
USERNAME="'admin'"
EOF

############################################
# Create REPO_DIR/pelican/.env
cat <<EOF > "$REPO_DIR/pelican/.env"
APP_ENV=production
APP_DEBUG=false
APP_KEY=base64:pFs0UbbnhgKAGSDKGIiuyAGSGFgkasfg3lHasdI4=
APP_URL="http://10082006.xyz:4000"
APP_INSTALLED=true
APP_LOCALE=en

DB_CONNECTION=mariadb
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=panel
DB_USERNAME=pelican
DB_PASSWORD=pelican#DB-SP1D3R
CACHE_STORE=redis
QUEUE_CONNECTION=redis
SESSION_DRIVER=redis
REDIS_HOST=127.0.0.1
REDIS_USERNAME=null
REDIS_PASSWORD=null
REDIS_PORT=6379
APP_NAME=SeevaramHomeserver
APP_LOGO=
APP_FAVICON=/pelican.ico
FILAMENT_TOP_NAVIGATION=true
FILAMENT_AVATAR_PROVIDER=gravatar
PANEL_USE_BINARY_PREFIX=true
APP_2FA_REQUIRED=0
TRUSTED_PROXIES=10082006.xyz
FILAMENT_WIDTH=screen-2xl
CAPTCHA_TURNSTILE_ENABLED=false
MAIL_MAILER=log
MAIL_FROM_ADDRESS="hello@example.com"
MAIL_FROM_NAME=Example
APP_BACKUP_DRIVER=wings
BACKUP_THROTTLE_LIMIT=2
BACKUP_THROTTLE_PERIOD=600
OAUTH_FACEBOOK_ENABLED=
OAUTH_X_ENABLED=
OAUTH_LINKEDIN_ENABLED=
OAUTH_GOOGLE_ENABLED=
OAUTH_GITHUB_ENABLED=
OAUTH_GITLAB_ENABLED=
OAUTH_BITBUCKET_ENABLED=
OAUTH_SLACK_ENABLED=
OAUTH_AUTHENTIK_ENABLED=
OAUTH_DISCORD_ENABLED=
OAUTH_STEAM_ENABLED=
PANEL_CLIENT_ALLOCATIONS_ENABLED=false
PANEL_SEND_INSTALL_NOTIFICATION=true
PANEL_SEND_REINSTALL_NOTIFICATION=true
GUZZLE_TIMEOUT=15
GUZZLE_CONNECT_TIMEOUT=5
APP_ACTIVITY_PRUNE_DAYS=90
APP_ACTIVITY_HIDE_ADMIN=false
APP_API_CLIENT_RATELIMIT=720
APP_API_APPLICATION_RATELIMIT=240
PANEL_EDITABLE_SERVER_DESCRIPTIONS=true
APP_WEBHOOK_PRUNE_DAYS=30
FILAMENT_UPLOADABLE_AVATARS=false
EOF

############################################
# Create REPO_DIR/pelican/.env.example
cat <<EOF > "$REPO_DIR/pelican/.env.example"
APP_ENV=production
APP_DEBUG=false
APP_KEY=
APP_URL=http://panel.test
APP_INSTALLED=false
APP_LOCALE=en
EOF

############################################
# === Apply suspicious permissions ===

# Unsafe permissions
chmod 777 "$REPO_DIR/service2/.env.local"
chmod 664 "$REPO_DIR/misc/config.env"
chmod 777 "$REPO_DIR/misc/binary.bin"

# Dangerous script with world-write + SUID bit
chmod 4777 "$REPO_DIR/scripts/hack.sh"

# World-writable script (legit but dangerous)
chmod 777 "$REPO_DIR/scripts/deploy.sh"

# SGID bit script
chmod 2755 "$REPO_DIR/scripts/setup.sh"

echo "Example monorepo created with valid and intentionally unsafe files and permissions."
