#!/usr/bin/env zsh

FACTORIO_DIR="$HOME/Library/Application Support/factorio"
MOD_NAME="factestio"
MOD_DIR="$FACTORIO_DIR/mods/$MOD_NAME"
MOD_LIST="$FACTORIO_DIR/mods/mod-list.json"

# Create symlink if it doesn't exist
if [ ! -d "$MOD_DIR" ]; then
  ln -s "$(pwd)" "$MOD_DIR"
  if [ -d "$MOD_DIR" ]; then
    echo "Symlink created for $MOD_NAME"
  fi
else
  echo "Symlink already exists for $MOD_NAME"
fi

# Enable the mod
if [ -f "$MOD_LIST" ]; then
  jq --arg mod_name "$MOD_NAME" '.mods |= map(if .name == $mod_name then .enabled = true else . end)' "$MOD_LIST" > "mod-list.tmp" && mv "mod-list.tmp" "$MOD_LIST"
  echo -n "Mod $MOD_NAME is enabled: "
  jq -r --arg mod_name "$MOD_NAME" '.mods[] | select(.name == $mod_name) | .enabled' "$MOD_LIST"
fi

