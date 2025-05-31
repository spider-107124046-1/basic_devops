#!/bin/bash

# Script should be run as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root."
    exit 1
fi

# Step 1: Input Directory as Argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <input_directory>"
    exit 1
fi

INPUT_DIR="$1"
if [ ! -d "$INPUT_DIR" ]; then
    echo "Error: Directory '$INPUT_DIR' does not exist."
    exit 1
fi

# Step 2: Setup .env.sanitized, logs/ and maintainer
VAULT_DIR="vault"
LOG_DIR="$VAULT_DIR/logs"
METADATA_LOG="$LOG_DIR/metadata.log"
OUT_FILE="$VAULT_DIR/.env.sanitized"
MAINTAINER="maintainer"

mkdir -p "$LOG_DIR" || { echo "Failed to create $LOG_DIR"; exit 1; }
touch "$METADATA_LOG" || { echo "Failed to create $METADATA_LOG"; exit 1; }
touch "$OUT_FILE" || { echo "Failed to create $OUT_FILE"; exit 1; }

if ! id "$MAINTAINER" &>/dev/null; then
    echo "Creating user '$MAINTAINER'..."
    sudo useradd -m "$MAINTAINER"
else
    echo "User '$MAINTAINER' already exists."
fi

echo "Vault Sweeper started at $(date)" | sudo tee -a "$METADATA_LOG"

# Step 3: ACTION!!!

check_permissions() {
    local file="$1"
    perm_warnings=()

    perm_octal=$(stat -c "%a" "$file")

    # SUID SGID Sticky -> 4 2 1
    if [[ ${#perm_octal} -ne 3 ]]; then
        special="${perm_octal:0:1}"
        [[ $((special & 4)) -ne 0 ]] && perm_warnings+=("Warning: $file has SUID bit set")
        [[ $((special & 2)) -ne 0 ]] && perm_warnings+=("Warning: $file has SGID bit set")
        [[ $((special & 1)) -ne 0 ]] && perm_warnings+=("Warning: $file has sticky bit set")
    fi
    [[ ${#perm_octal} -eq 3 ]] && perm_octal="0$perm_octal" # Ensure 4 digits for octal permissions

    owner=${perm_octal:1:1}
    group=${perm_octal:2:1}
    others=${perm_octal:3:1}

    # Check group permissions
    # [[ $((group & 4)) -ne 0 ]] && perm_warnings+=("Warning: $file is group-readable ($perm_octal)")
    [[ $((group & 2)) -ne 0 ]] && perm_warnings+=("Warning: $file is group-writable ($perm_octal)")
    [[ $((group & 1)) -ne 0 ]] && perm_warnings+=("Warning: $file is group-executable ($perm_octal)")

    # Check others (world) permissions
    [[ $((others & 4)) -ne 0 ]] && perm_warnings+=("Warning: $file is world-readable ($perm_octal)")
    [[ $((others & 2)) -ne 0 ]] && perm_warnings+=("Warning: $file is world-writable ($perm_octal)")
    [[ $((others & 1)) -ne 0 ]] && perm_warnings+=("Warning: $file is world-executable ($perm_octal)")
}

log_metadata() {
    local file="$1"
    # Nameref in bash 4.3+ https://stackoverflow.com/questions/10582763/how-to-return-an-array-in-bash-without-using-globals
    check_permissions "$file" perm_warnings

    perm_octal=$(stat -c "%a" "$file")
    [[ ${#perm_octal} -eq 3 ]] && perm_octal="0$perm_octal"

    # Log metadata
    {
        echo "File: $file"
        echo "$(stat -c 'User: UID=%u (%U), GID=%g (%G)' "$file")"
        echo "$(stat -c 'Last modified: by %U on %y' "$file")"

        echo "Permissions: $perm_octal"
        echo "Access Control List:"
        echo "$(getfacl "$file" 2>/dev/null | grep -v '^#' | grep -v '^$' || echo 'No ACL set')"
        echo "Extended Attributes:"
        echo "$(getfattr -d "$file" 2>/dev/null | grep -v '^#' | grep -v '^$' || echo 'No extended attributes')"
        [[ ${#perm_warnings[@]} -gt 0 ]] && printf "  - %s\n" "${perm_warnings[@]}"

        if [[ "$(basename "$item")" == *.env* ]]; then
            echo "Valid Lines: ${#valid[@]}"
            echo "Invalid Lines: ${#invalid[@]}"
            echo "Rejected Lines:"
            printf "  - %s\n" "${invalid[@]}"
        fi
        echo "---"
    } >> "$METADATA_LOG"
    echo "Metadata logged for $file"
}

validate_env_vars() {
    local file="$1"
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^# ]] && valid+=("$line") && continue

        # Space around =
        if [[ "$line" =~ ^[A-Z_][A-Z0-9_]*=.* ]]; then
            key="${line%%=*}"
            value="${line#*=}"

            # Unsafe keys
            if [[ "$key" =~ (PASSWORD|PRIVATE_KEY|SECRET|TOKEN|PATH|LD_PRELOAD|LD_LIBRARY_PATH) ]]; then
                invalid+=("$line")
            
            # if $value has unnecessary quotation marks
            elif [[ "$value" =~ ^\".*\"$ || "$value" =~ ^\'.*\'$ ]]; then
                quote_char="${value:0:1}"
                actual_value="${value:1:-1}"

                # somewhat works?
                # ^| because it didnt match " or ' at the start of the string
                if [[ "$actual_value" =~ (^|[^\\])"$quote_char" ]]; then
                    invalid+=("$line")
                # because it didnt match multiple quote wrappers
                elif [[ "$actual_value" =~ ^[\"\']+.*[\"\']+$ ]]; then
                    invalid+=("$line")
                elif [[ "$actual_value" =~ [[:space:]#\$!\&*\'\"\`] ]]; then
                    valid+=("$line")
                else
                    invalid+=("$line")
                fi

            elif [[ "${value:0:1}" =~ [\"\'] ]]; then
                invalid+=("$line")

            else
                valid+=("$line")
            fi
        elif [[ "${line:0:1}" == "#" ]]; then
            # Preserve comments
            valid+=("$line")
        elif [[ -z "$line" ]]; then
            # Preserve empty lines
            valid+=("$line")
        else
            invalid+=("$line")
        fi
    done < "$file"

    local tmp_file=$(mktemp)
    # Remove invalid lines from the original file
    grep -vxFf <(printf "%s\n" "${invalid[@]}") "$file" > "$tmp_file" && mv "$tmp_file" "$file"

    # Output sanitized environment - in single file as directed by Aakash
    echo "## $file START ##" >> "$OUT_FILE"
    printf "%s\n" "${valid[@]}" >> "$OUT_FILE"
    echo "## $file END ##" >> "$OUT_FILE"

    echo "Sanitized environment variables from $file written to $OUT_FILE"
}

scan_directory() {
    local dir="$INPUT_DIR"
    echo "Scanning directory: $dir"
    # (self note: -print0 = null delimiter, IFS= means Internal Field Separator, set to null)
    find "$dir" -print0 | while IFS= read -r -d '' item; do
        if [ -d "$item" ]; then
            echo "Found folder: $item"
            log_metadata "$item"
        elif [ -f "$item" ]; then
            if [[ "$(basename "$item")" == *.env* ]]; then
                echo "Found env file: $item"
                validate_env_vars "$item"
                log_metadata "$item"
            else
                echo "Found file: $item"
                log_metadata "$item"
            fi
        fi
    done
}

scan_directory

# all 3 used even with -R to allow user to edit the variable manually without needing much change
sudo chown -R "$MAINTAINER":"$MAINTAINER" "$VAULT_DIR" "$LOG_DIR" "$METADATA_LOG" "$OUT_FILE"
sudo chmod -R 755 "$VAULT_DIR" "$LOG_DIR" "$METADATA_LOG" "$OUT_FILE"

# ask if user wants to lock sanitized env file
read -rp "Do you want to lock the sanitized env file ($OUT_FILE)? (Y/n) > " lock_choice
if [[ -z "$lock_choice" || "$lock_choice" =~ ^[Yy]$ ]]; then
    sudo chmod 600 "$OUT_FILE" # chattr +i is not available on every filesystem, only ext4
    echo "Sanitized env file locked."
fi

# Step 4: Set up vault scan cronjob
sudo cp "$0" /usr/local/bin/vault_sweeper.sh
CRON_SCAN_SCRIPT="/usr/local/bin/vault_cron_scan.sh"
ALERT_USER="$MAINTAINER"

# Prompt user before setting up cronjob
read -rp "Do you want to set up a cronjob to scan the vault every 6 hours? (Y/n) > " cron_choice
if [[ -z "$cron_choice" || "$cron_choice" =~ ^[Yy]$ ]]; then
    # Heredoc 
    cat <<EOF | sudo tee "$CRON_SCAN_SCRIPT" > /dev/null
#!/bin/bash

INPUT_DIR="$(realpath "$INPUT_DIR")"
VAULT_DIR="\$INPUT_DIR/../vault"
METADATA_LOG="\$VAULT_DIR/logs/metadata.log"
ALERT_USER="$ALERT_USER"
ALERT_LOG="/tmp/vault_alert.log"
TIMESTAMP=\$(date '+%Y-%m-%d %H:%M:%S')

sudo /usr/local/bin/vault_sweeper.sh "\$INPUT_DIR"

if grep -q '\- Warning:' "\$METADATA_LOG"; then
    echo "ALERT: Warning(s) detected in \$METADATA_LOG during the Vault Sweeper scan. Please review." >> "\$ALERT_LOG"
    if command -v mail >/dev/null 2>&1; then
        echo "ALERT: Warning(s) detected in \$METADATA_LOG during the Vault Sweeper scan. Please review." | mail -s "Vault Alert" "\$ALERT_USER"
    fi
fi

if grep -A 10 '^Rejected Lines:' "\$METADATA_LOG" | grep -q '  - '; then
    echo "ALERT: Rejected environment lines found in \$METADATA_LOG and have been removed" >> "\$ALERT_LOG"
    if command -v mail >/dev/null 2>&1; then
        echo "Vault Sweeper has rejected some environment lines. Please review the log." | mail -s "Vault env sanitization" "\$ALERT_USER"
    fi
fi

EOF

    sudo chmod +x "$CRON_SCAN_SCRIPT"
    echo "Vault cron scan script created at $CRON_SCAN_SCRIPT"

    # Add cronjob that runs scan every 6 hours
    CRON_ENTRY="0 */6 * * * $CRON_SCAN_SCRIPT"
    CRONTAB_EXISTS=$(sudo crontab -l 2>/dev/null | grep -F "$CRON_SCAN_SCRIPT")

    if [[ -z "$CRONTAB_EXISTS" ]]; then
        (sudo crontab -l 2>/dev/null; echo "$CRON_ENTRY") | sudo crontab -
        echo "Cronjob added to run vault scan every 6 hours."
    else
        echo "Cronjob already exists. Skipping re-addition."
    fi
else
    echo "Skipping cronjob setup."
fi
