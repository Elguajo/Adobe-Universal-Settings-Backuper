#!/bin/bash

# CAN: Adobe Ultimate Backup Tool (Custom Scripts Only)
# Version: 3.5
# Author: CAN

# ==========================================
# CONFIGURATION
# ==========================================
BACKUP_ROOT="$HOME/Desktop/Backups"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
CURRENT_BACKUP_FOLDER="$BACKUP_ROOT/Adobe_Backup_$TIMESTAMP"

# Standard Exclusions (Cache, Logs, System Junk)
RSYNC_EXCLUDES=(
    --exclude="*Cache*" 
    --exclude="*Caches*" 
    --exclude="*.tmp" 
    --exclude="*.lock" 
    --exclude="*.log" 
    --exclude="*Log*" 
    --exclude="*Logs*" 
    --exclude=".DS_Store" 
    --exclude="Creative Cloud Libraries" 
    --exclude="OOBE" 
    --exclude="Team Projects Local Hub" 
    --exclude="CC_LIBRARIES_PANEL_EXTENSION*" 
    --exclude="ACPLocal*"
)

# Plugins Exclusions (Standard Adobe Plugins)
PLUGIN_EXCLUDES=(
    --exclude="(AdobePSL)"
    --exclude="Cineware by Maxon"
    --exclude="Effects"
    --exclude="Extensions"
    --exclude="Format"
    --exclude="Keyframe"
)

# ==========================================
# GUI HELPER FUNCTIONS
# ==========================================

function shell_quote() {
    local s="$1"
    s=${s//\'/\'\\\'\'}
    printf "'%s'" "$s"
}

function run_admin_cmd() {
    local cmd="$1"
    osascript <<'APPLESCRIPT' "$cmd"
on run argv
  set cmd to item 1 of argv
  do shell script cmd with administrator privileges
end run
APPLESCRIPT
}

function show_menu() {
    osascript <<EOD
    set question to display dialog "Adobe Manager v3.5\n\nBackup/Restore:\n- Preferences\n- Custom Plugins Only\n- ScriptUI Panels Only (No default scripts)\n\n(Cleanest possible backup)" buttons {"Cancel", "Restore", "Backup"} default button "Backup" with icon note
    return button returned of question
EOD
}

function show_notification() {
    osascript -e "display notification \"$1\" with title \"Adobe Manager\""
}

function show_alert() {
    osascript -e "display dialog \"$1\" buttons {\"OK\"} default button \"OK\" with icon caution"
}

function show_success() {
    osascript -e "display dialog \"$1\" buttons {\"OK\"} default button \"OK\" with icon note"
}

function is_noise_preference() {
    local name
    name=$(basename "$1")

    case "$name" in
        com.adobe.*.plist|\
        *"Creative Cloud"*|*"CoreSync"*|*"CCXProcess"*|*"AdobeGCClient"*|\
        *"Updater"*|*"Update"*|*"Sync"*|*"MRU"*|*"Recent"*)
            return 0
            ;;
    esac

    return 1
}

function installed_adobe_preference_keys() {
    find /Applications -maxdepth 3 \( -type d -name "Adobe *.app" -o -type d -name "Adobe *" \) -print0 2>/dev/null | \
    while IFS= read -r -d '' item; do
        local name
        name=$(basename "$item" .app)

        case "$name" in
            *"Creative Cloud"*|*"Updater"*|*"Update"*|*"CoreSync"*|*"CCXProcess"*)
                continue
                ;;
        esac

        printf '%s\n' "$name"

        local info_plist="$item/Contents/Info.plist"
        if [ -f "$info_plist" ]; then
            local major_version product_key
            major_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$info_plist" 2>/dev/null | cut -d. -f1)
            product_key=$(printf '%s\n' "$name" | sed -E 's/[[:space:]][0-9]{4}$//')

            if [ -n "$major_version" ] && [ -n "$product_key" ]; then
                printf '%s %s\n' "$product_key" "$major_version"
            fi
        fi
    done | sort -u
}

function should_backup_adobe_preference() {
    local path="$1"
    local name
    name=$(basename "$path")

    if is_noise_preference "$path"; then
        return 1
    fi

    if [ -d "$path" ] && [[ "$name" == Adobe*" Settings" ]]; then
        local settings_key="${name% Settings}"
        if ! printf '%s\n' "${INSTALLED_ADOBE_PREF_KEYS[@]}" | grep -Fxq "$settings_key"; then
            return 1
        fi
    fi

    return 0
}

function select_folder() {
    if [ ! -d "$BACKUP_ROOT" ]; then mkdir -p "$BACKUP_ROOT"; fi
    osascript <<EOD
    set startPath to POSIX file "$BACKUP_ROOT"
    try
        set folderPath to choose folder with prompt "Select Backup to Restore:" default location startPath
        return POSIX path of folderPath
    on error
        return "UserCanceled"
    end try
EOD
}

function manifest_init() {
    MANIFEST_FILE="$CURRENT_BACKUP_FOLDER/manifest.tsv"
    META_FILE="$CURRENT_BACKUP_FOLDER/meta.tsv"

    mkdir -p "$CURRENT_BACKUP_FOLDER"
    printf 'backup_path\trestore_parent\tadmin\n' > "$MANIFEST_FILE"
    printf 'created\t%s\n' "$TIMESTAMP" > "$META_FILE"
    printf 'host\t%s\n' "$(scutil --get ComputerName 2>/dev/null || hostname)" >> "$META_FILE"
}

function manifest_path() {
    local path="$1"
    path="${path%/}"
    printf '%s' "${path#"$CURRENT_BACKUP_FOLDER"/}"
}

function manifest_add() {
    local backup_path="$1"
    local restore_parent="$2"
    local admin="$3"

    printf '%s\t%s\t%s\n' "$(manifest_path "$backup_path")" "$restore_parent" "$admin" >> "$MANIFEST_FILE"
}

function restore_manifest_item() {
    local source_root="$1"
    local backup_path="$2"
    local restore_parent="$3"
    local admin="$4"

    local source_path="$source_root/$backup_path"
    if [ ! -e "$source_path" ]; then
        echo "Skipping missing manifest item: $source_path"
        return
    fi

    if [ "$admin" = "true" ]; then
        ADMIN_CMDS+=("rsync -a -v $(shell_quote "$source_path") $(shell_quote "$restore_parent")")
    else
        rsync -a -v "$source_path" "$restore_parent"
    fi
}

function restore_from_manifest() {
    local source_root="$1"
    local manifest="$source_root/manifest.tsv"

    if [ ! -f "$manifest" ]; then
        return 1
    fi

    while IFS=$'\t' read -r backup_path restore_parent admin; do
        restore_manifest_item "$source_root" "$backup_path" "$restore_parent" "$admin"
    done < <(tail -n +2 "$manifest")

    return 0
}

# ==========================================
# BACKUP LOGIC
# ==========================================

function do_backup() {
    echo "--- Starting Backup ---"
    manifest_init
    
    # --- 1. User Library Settings ---
    local APP_SUPPORT="$HOME/Library/Application Support/Adobe"
    local PREFS="$HOME/Library/Preferences"
    local DEST_USER="$CURRENT_BACKUP_FOLDER/User_Library"
    local INSTALLED_ADOBE_PREF_KEYS
    IFS=$'\n' read -r -d '' -a INSTALLED_ADOBE_PREF_KEYS < <(installed_adobe_preference_keys && printf '\0')
    
    mkdir -p "$DEST_USER/Application Support"
    mkdir -p "$DEST_USER/Preferences"

    # Backup Main Adobe Support
    if [ -d "$APP_SUPPORT" ]; then
        echo "Backing up User Application Support..."
        rsync -a -v "${RSYNC_EXCLUDES[@]}" "$APP_SUPPORT" "$DEST_USER/Application Support/"
        manifest_add "$DEST_USER/Application Support/Adobe" "$HOME/Library/Application Support/" false
    fi

    # Backup Preferences Files
    echo "Backing up User Preferences..."
    find "$PREFS" -maxdepth 1 -name "*Adobe*" -print0 | while IFS= read -r -d '' f; do
        if should_backup_adobe_preference "$f"; then
            rsync -a -v "${RSYNC_EXCLUDES[@]}" "$f" "$DEST_USER/Preferences/"
            manifest_add "$DEST_USER/Preferences/$(basename "$f")" "$HOME/Library/Preferences/" false
        else
            echo "Skipping noise/stale preference: $f"
        fi
    done

    # --- 2. System Wide Items (Plugins/Scripts in Applications) ---
    local DEST_SYSTEM="$CURRENT_BACKUP_FOLDER/System_Apps_Data"
    mkdir -p "$DEST_SYSTEM"
    
    echo "Scanning Applications for Custom Plugins and ScriptUI Panels..."
    
    find /Applications -maxdepth 2 -type d -name "Adobe *" -print0 | while IFS= read -r -d '' app_path; do
        
        # A. PLUGINS (Exclude standard ones)
        if [ -d "$app_path/Plug-ins" ]; then
            echo "Found Plugins: $app_path"
            mkdir -p "$DEST_SYSTEM$app_path" 
            rsync -a -v "${RSYNC_EXCLUDES[@]}" "${PLUGIN_EXCLUDES[@]}" "$app_path/Plug-ins" "$DEST_SYSTEM$app_path/"
            manifest_add "$DEST_SYSTEM$app_path/Plug-ins" "$app_path/" true
        fi

        # B. SCRIPTS (ONLY ScriptUI Panels)
        # We specifically target the "ScriptUI Panels" folder inside Scripts
        if [ -d "$app_path/Scripts/ScriptUI Panels" ]; then
            echo "Found ScriptUI Panels: $app_path"
            # Create structure: AppName/Scripts/
            mkdir -p "$DEST_SYSTEM$app_path/Scripts"
            # Backup ONLY "ScriptUI Panels" folder
            rsync -a -v "${RSYNC_EXCLUDES[@]}" "$app_path/Scripts/ScriptUI Panels" "$DEST_SYSTEM$app_path/Scripts/"
            manifest_add "$DEST_SYSTEM$app_path/Scripts/ScriptUI Panels" "$app_path/Scripts/" true
        fi
    done

    # --- 3. System Library (Common Plugins/CEP) ---
    local SYS_LIB_ADOBE="/Library/Application Support/Adobe"
    local DEST_SYS_LIB="$CURRENT_BACKUP_FOLDER/System_Library_Adobe"
    
    if [ -d "$SYS_LIB_ADOBE/Common/Plug-ins" ]; then
        echo "Backing up MediaCore Plugins..."
        mkdir -p "$DEST_SYS_LIB/Common"
        rsync -a -v "${RSYNC_EXCLUDES[@]}" "$SYS_LIB_ADOBE/Common/Plug-ins" "$DEST_SYS_LIB/Common/"
        manifest_add "$DEST_SYS_LIB/Common/Plug-ins" "/Library/Application Support/Adobe/Common/" true
    fi

    if [ -d "$SYS_LIB_ADOBE/CEP" ]; then
        echo "Backing up System CEP Extensions..."
        mkdir -p "$DEST_SYS_LIB"
        rsync -a -v "${RSYNC_EXCLUDES[@]}" "$SYS_LIB_ADOBE/CEP" "$DEST_SYS_LIB/"
        manifest_add "$DEST_SYS_LIB/CEP" "/Library/Application Support/Adobe/" true
    fi

    show_success "Backup Complete!\nOnly custom plugins and ScriptUI Panels saved."
    show_notification "Backup Successful"
}

# ==========================================
# RESTORE LOGIC
# ==========================================

function do_restore() {
    local SOURCE=$(select_folder)
    if [[ "$SOURCE" == "UserCanceled" ]]; then exit 0; fi

    echo "--- Starting Restore ---"

    local -a ADMIN_CMDS=()

    if restore_from_manifest "$SOURCE"; then
        if [ "${#ADMIN_CMDS[@]}" -gt 0 ]; then
            echo "Restoring privileged manifest items..."
            local joined=""
            local c
            for c in "${ADMIN_CMDS[@]}"; do
                if [ -n "$joined" ]; then
                    joined="$joined; $c"
                else
                    joined="$c"
                fi
            done
            run_admin_cmd "$joined"
        fi

        show_success "Restore Complete!\nManifest-based restore completed."
        show_notification "Restore Successful"
        return
    fi

    # --- 1. Restore User Data ---
    if [ -d "$SOURCE/User_Library/Application Support/Adobe" ]; then
        echo "Restoring User Settings..."
        rsync -a -v "${RSYNC_EXCLUDES[@]}" "$SOURCE/User_Library/Application Support/Adobe" "$HOME/Library/Application Support/"
    fi

    if [ -d "$SOURCE/User_Library/Preferences" ]; then
        echo "Restoring Preferences..."
        rsync -a -v "${RSYNC_EXCLUDES[@]}" "$SOURCE/User_Library/Preferences/" "$HOME/Library/Preferences/"
    fi

    # --- 2. Restore System Data (With Admin Privileges) ---
    local NEEDS_SUDO=false

    if [ -d "$SOURCE/System_Apps_Data" ]; then
        NEEDS_SUDO=true
        # Safety checks: only allow restoring into /Applications via the saved structure.
        if [ ! -d "$SOURCE/System_Apps_Data/Applications" ]; then
            show_alert "Invalid backup structure.\nExpected: System_Apps_Data/Applications\n\nAborting restore."
            exit 1
        fi
        if find "$SOURCE/System_Apps_Data" -mindepth 1 -maxdepth 1 -type d ! -name "Applications" -print -quit | grep -q .; then
            show_alert "Invalid backup structure.\nSystem_Apps_Data contains unexpected top-level folders.\n\nAborting restore."
            exit 1
        fi
        # Intentionally no exclude patterns here: safer quoting and predictable restore target.
        ADMIN_CMDS+=("rsync -a -v $(shell_quote "$SOURCE/System_Apps_Data/Applications/") $(shell_quote "/Applications/")")
    fi

    if [ -d "$SOURCE/System_Library_Adobe" ]; then
        NEEDS_SUDO=true
        if [ ! -d "$SOURCE/System_Library_Adobe" ]; then
            show_alert "Invalid backup structure.\nExpected: System_Library_Adobe\n\nAborting restore."
            exit 1
        fi
        # Intentionally no exclude patterns here: safer quoting and predictable restore target.
        ADMIN_CMDS+=("rsync -a -v $(shell_quote "$SOURCE/System_Library_Adobe/") $(shell_quote "/Library/Application Support/Adobe/")")
    fi

    if [ "$NEEDS_SUDO" = true ]; then
        echo "Restoring System Scripts/Plugins..."
        # Build one command string for a single admin prompt.
        local joined=""
        local c
        for c in "${ADMIN_CMDS[@]}"; do
            if [ -n "$joined" ]; then
                joined="$joined; $c"
            else
                joined="$c"
            fi
        done
        run_admin_cmd "$joined"
    fi

    show_success "Restore Complete!\nCustom plugins and ScriptUI Panels restored."
    show_notification "Restore Successful"
}

# ==========================================
# EXECUTION
# ==========================================

if ! command -v rsync &> /dev/null; then
    show_alert "Error: rsync not found."
    exit 1
fi

SELECTION=$(show_menu)

if [[ "$SELECTION" == "Backup" ]]; then
    do_backup
elif [[ "$SELECTION" == "Restore" ]]; then
    do_restore
else
    exit 0
fi
