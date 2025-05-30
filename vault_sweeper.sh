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

# Step 2: Setup logs/ and maintainer
LOG_DIR="$VAULT_DIR/logs"
mkdir -p "$LOG_DIR"

if ! id "maintainer" &>/dev/null; then
    echo "Creating user 'maintainer'..."
    sudo useradd -m maintainer
else
    echo "User 'maintainer' already exists."
fi

chown maintainer:maintainer "$LOG_DIR"
chmod 700 "$LOG_DIR"
touch "$LOG_DIR/metadata.log"

