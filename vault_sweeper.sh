#!/bin/bash

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
mkdir -p "$LOG_DIR"
touch "$METADATA_LOG"

touch .env.sanitized || OUT_FILE=.env.sanitized
if [ ! -f "$OUT_FILE" ]; then
    echo "Error: Could not create output file '$OUT_FILE'."
    exit 1
fi

if ! id "maintainer" &>/dev/null; then
    echo "Creating user 'maintainer'..."
    sudo useradd -m maintainer
else
    echo "User 'maintainer' already exists."
fi

# all 3 used even with -R to allow user to edit the variable manually without needing much change
sudo chown -R maintainer:maintainer "$VAULT_DIR" "$LOG_DIR" "$METADATA_LOG" "$OUT_FILE"
sudo chmod -R 700 "$VAULT_DIR" "$LOG_DIR" "$METADATA_LOG" "$OUT_FILE"

echo "Vault Sweeper started at $(date)" >> "$METADATA_LOG"

# ok i will write the functions first

scan_directory() {
    local dir="$INPUT_DIR"
    echo "Scanning directory: $dir"
    # if they ask for folders also, (self note: -print0 = null delimiter, IFS= means Internal Field Separator, set to null)
    find "$dir" -print0 | while IFS= read -r -d '' item; do
        if [ -d "$item" ]; then
            echo "Found folder: $item"
            # processing logic for each folder
        elif [ -f "$item" ]; then
            if [[ "$(basename "$item")" == *.env* ]]; then
                echo "Found env file: $item"
                # processing logic for each env file
            else
                echo "Found file: $item"
                # processing logic for each file
            fi
        fi
    done
}

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
    [[ $((group & 4)) -ne 0 ]] && perm_warnings+=("Warning: $file is group-readable ($perm_octal)")
    [[ $((group & 2)) -ne 0 ]] && perm_warnings+=("Warning: $file is group-writable ($perm_octal)")
    [[ $((group & 1)) -ne 0 ]] && perm_warnings+=("Warning: $file is group-executable ($perm_octal)")

    # Check others (world) permissions
    [[ $((others & 4)) -ne 0 ]] && perm_warnings+=("Warning: $file is world-readable ($perm_octal)")
    [[ $((others & 2)) -ne 0 ]] && perm_warnings+=("Warning: $file is world-writable ($perm_octal)")
    [[ $((others & 1)) -ne 0 ]] && perm_warnings+=("Warning: $file is world-executable ($perm_octal)")

}

log_metadata() {
    local file="$1"
    local metadata_log="$LOG_DIR/metadata.log"
    local valid=()
    local invalid=()
    # Nameref in bash 4.3+ https://stackoverflow.com/questions/10582763/how-to-return-an-array-in-bash-without-using-globals
    check_permissions perm_warnings

    ### start env file processing
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^# ]] && continue

        # Space around =
        if [[ "$line" =~ ^[A-Z_][A-Z0-9_]*=.* ]]; then
            key="${line%%=*}"
            value="${line#*=}"

            # Unsafe keys
            if [[ "$key" =~ (PASSWORD|SECRET|TOKEN|PATH|LD_PRELOAD|LD_LIBRARY_PATH) ]]; then
                invalid+=("$line")
            
            # if $value has unnecessary quotation marks
            elif [[ "$value" =~ ^\".*\"$ || "$value" =~ ^\'.*\'$ ]]; then
                quote_char="${value:0:1}"
                actual_value="${value:1:-1}"
                # ^| because it didnt match " or ' at the start of the string
                if [[ "$actual_value" =~ (^|[^\\])$quote_char ]]; then
                    invalid+=("$line")
                elif [[ "$actual_value" =~ [[:space:]#\$!&*\'\"\`] ]]; then
                    valid+=("$line")
                else
                    invalid+=("$line")
                fi

            else
                valid+=("$line")
            fi
        else
            invalid+=("$line")
        fi
    done < "$file"

    # Output sanitized environment
    printf "%s\n" "${valid[@]}" > "$out_file"
    chmod 600 "$out_file"
    chown "$MAINTAINER_USER":"$MAINTAINER_USER" "$out_file"
    ### end env file processing

    perm_octal=$(stat -c "%a" "$file")
    [[ ${#perm_octal} -eq 3 ]] && perm_octal="0$perm_octal"

    # Log metadata
    {
        echo "File: $file"
        stat "$file"
        echo "User: $(stat -c '%U' "$file")"
        echo "Permissions: $perm_octal"
        for warning in "${perm_warnings[@]}"; do
            echo "  - $warning"
        done
        if [[ "$(basename "$item")" == *.env* ]]; then
            echo "Valid Lines: ${#valid[@]}"
            echo "Invalid Lines: ${#invalid[@]}"
            echo "Rejected Lines:"
            for l in "${invalid[@]}"; do
                echo "  - $l"
            done
        fi
        echo "---"
    } >> "$metadata_log"
    echo "Metadata logged for $file"

}