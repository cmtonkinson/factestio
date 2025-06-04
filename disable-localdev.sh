#!/usr/bin/env zsh

FACTORIO_DIR="$HOME/Library/Application Support/factorio"
MOD_NAME="factestio"
MOD_DIR="$FACTORIO_DIR/mods/$MOD_NAME"
MOD_LIST="$FACTORIO_DIR/mods/mod-list.json"

# Remove symlink if it exists and is a symlink
if [ -L "$MOD_DIR" ]; then
  rm "$MOD_DIR"
  if [ ! -e "$MOD_DIR" ]; then
    echo "Symlink removed for $MOD_NAME"
  fi
elif [ -e "$MOD_DIR" ]; then
  echo "Warning: $MOD_DIR exists but is not a symlink. Not removing."
fi

# Disable the mod
if [ -f "$MOD_LIST" ]; then
  jq --arg mod_name "$MOD_NAME" '.mods |= map(if .name == $mod_name then .enabled = false else . end)' "$MOD_LIST" > "mod-list.tmp" && mv "mod-list.tmp" "$MOD_LIST"
  echo -n "Mod $MOD_NAME is enabled: "
  jq -r --arg mod_name "$MOD_NAME" '.mods[] | select(.name == $mod_name) | .enabled' "$MOD_LIST"
fi

