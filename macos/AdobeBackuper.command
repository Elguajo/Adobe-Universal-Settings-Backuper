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

# ==========================================
# BACKUP LOGIC
# ==========================================

function do_backup() {
    echo "--- Starting Backup ---"
    
    # --- 1. User Library Settings ---
    local APP_SUPPORT="$HOME/Library/Application Support/Adobe"
    local PREFS="$HOME/Library/Preferences"
    local DEST_USER="$CURRENT_BACKUP_FOLDER/User_Library"
    
    mkdir -p "$DEST_USER/Application Support"
    mkdir -p "$DEST_USER/Preferences"

    # Backup Main Adobe Support
    if [ -d "$APP_SUPPORT" ]; then
        echo "Backing up User Application Support..."
        rsync -a -v "${RSYNC_EXCLUDES[@]}" "$APP_SUPPORT" "$DEST_USER/Application Support/"
    fi

    # Backup Preferences Files
    echo "Backing up User Preferences..."
    find "$PREFS" -maxdepth 1 -name "*Adobe*" -print0 | while IFS= read -r -d '' f; do
        rsync -a -v "${RSYNC_EXCLUDES[@]}" "$f" "$DEST_USER/Preferences/"
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
        fi

        # B. SCRIPTS (ONLY ScriptUI Panels)
        # We specifically target the "ScriptUI Panels" folder inside Scripts
        if [ -d "$app_path/Scripts/ScriptUI Panels" ]; then
            echo "Found ScriptUI Panels: $app_path"
            # Create structure: AppName/Scripts/
            mkdir -p "$DEST_SYSTEM$app_path/Scripts"
            # Backup ONLY "ScriptUI Panels" folder
            rsync -a -v "${RSYNC_EXCLUDES[@]}" "$app_path/Scripts/ScriptUI Panels" "$DEST_SYSTEM$app_path/Scripts/"
        fi
    done

    # --- 3. System Library (Common Plugins/CEP) ---
    local SYS_LIB_ADOBE="/Library/Application Support/Adobe"
    local DEST_SYS_LIB="$CURRENT_BACKUP_FOLDER/System_Library_Adobe"
    
    if [ -d "$SYS_LIB_ADOBE/Common/Plug-ins" ]; then
        echo "Backing up MediaCore Plugins..."
        mkdir -p "$DEST_SYS_LIB/Common"
        rsync -a -v "${RSYNC_EXCLUDES[@]}" "$SYS_LIB_ADOBE/Common/Plug-ins" "$DEST_SYS_LIB/Common/"
    fi

    if [ -d "$SYS_LIB_ADOBE/CEP" ]; then
        echo "Backing up System CEP Extensions..."
        mkdir -p "$DEST_SYS_LIB"
        rsync -a -v "${RSYNC_EXCLUDES[@]}" "$SYS_LIB_ADOBE/CEP" "$DEST_SYS_LIB/"
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
    local -a ADMIN_CMDS=()

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
