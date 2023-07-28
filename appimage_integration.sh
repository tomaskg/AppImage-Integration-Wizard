#!/bin/bash

# Constants
CONFIG_FILE="$HOME/.appimage_integration.conf"
LOG_FILE="$HOME/appimage_integration.log"
DEFAULT_CATEGORIES="Utility;Development;Graphics"
USER_DESKTOP_ENTRY_DIR="$HOME/.local/share/applications"

# Function to log messages with different log levels
log() {
  local level=$1
  local message=$2
  if [ "$LOG_LEVEL" == "DEBUG" ] || [ "$LOG_LEVEL" == "$level" ]; then
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $level - $message" >> "$LOG_FILE"
  fi
}

# Function to prompt for user input and validate file existence
prompt_for_file() {
  local input_variable=$1
  local message=$2

  read -p "$message" "$input_variable"

  while [[ ! -f ${!input_variable} ]]; do
    echo "Error: The specified file does not exist. Please check the path and try again."
    log "ERROR" "The specified file does not exist: ${!input_variable}"
    read -p "$message" "$input_variable"
  done
}

# Function to prompt for user confirmation
confirm() {
  local prompt_message=$1
  local confirmation_message=$2

  if [ -n "$confirmation_message" ]; then
    echo "$confirmation_message"
    log "INFO" "$confirmation_message"
  fi

  read -p "$prompt_message (y/n): " choice
  case "$choice" in
    y|Y ) return 0;;
    n|N ) return 1;;
    * ) echo "Error: Invalid input. Please enter 'y' or 'n'." && return 1;;
  esac
}

# Function to read or create the configuration file
load_config() {
  if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
  else
    APP_NAME=""
    APP_DESCRIPTION=""
    APP_IMAGE_PATH=""
    APP_ICON_PATH=""
    APP_CATEGORIES="$DEFAULT_CATEGORIES"
  fi
}

# Function to save the configuration to the file
save_config() {
  cat << EOF > "$CONFIG_FILE"
APP_NAME="$APP_NAME"
APP_DESCRIPTION="$APP_DESCRIPTION"
APP_IMAGE_PATH="$APP_IMAGE_PATH"
APP_ICON_PATH="$APP_ICON_PATH"
APP_CATEGORIES="$APP_CATEGORIES"
EOF
}

# Function to create a backup of existing desktop entry files
backup_desktop_entries() {
  local backup_dir="$HOME/appimage_integration_backup_$(date +"%Y%m%d%H%M%S")"

  if [ ! -d "$backup_dir" ]; then
    mkdir "$backup_dir"
    log "INFO" "Backup directory created: $backup_dir"

    cp "$USER_DESKTOP_ENTRY_DIR/$APP_NAME.desktop" "$backup_dir"
    log "INFO" "Desktop entry backed up: $backup_dir/$APP_NAME.desktop"
  fi
}

# Function to restore desktop entry files from backup
restore_desktop_entries() {
  local backup_dir=$(ls -d "$HOME/appimage_integration_backup_"* | tail -1)

  if [ -d "$backup_dir" ]; then
    cp "$backup_dir/$APP_NAME.desktop" "$USER_DESKTOP_ENTRY_DIR/$APP_NAME.desktop"
    log "INFO" "Desktop entry restored from backup: $USER_DESKTOP_ENTRY_DIR/$APP_NAME.desktop"
  else
    echo "Warning: No backup directory found. Nothing to restore."
    log "WARNING" "No backup directory found. Nothing to restore."
  fi
}

# Function to integrate a new AppImage
integrate_appimage() {
  echo "🌟 Integration Wizard - New AppImage Integration 🌟"

  # Step 1: App Name
  echo "🏷️ Step 1: Enter the Name of Your App 🏷️"
  echo "This is the name that will appear in the application menu."
  read -p "Please enter the name of your app: " APP_NAME

  while [[ -z "$APP_NAME" ]]; do
    echo "Error: The app name can't be empty. Please try again."
    log "ERROR" "App Name cannot be empty."
    read -p "Please enter the name of your app: " APP_NAME
  done

  # Step 2: App Description
  echo "📝 Step 2: Enter a Brief Description 📝"
  echo "Let's describe your app in a few words."
  read -p "Please provide a brief description of your app: " APP_DESCRIPTION

  while [[ -z "$APP_DESCRIPTION" ]]; do
    echo "Error: The description can't be empty. Please try again."
    log "ERROR" "App Description cannot be empty."
    read -p "Please provide a brief description of your app: " APP_DESCRIPTION
  done

  # Step 3: AppImage Path
  echo "📂 Step 3: Locate Your AppImage 📂"
  echo "Please tell me where your AppImage file is located."
  prompt_for_file "APP_IMAGE_PATH" "Please provide the path to your AppImage file: "

  # Step 4: Icon File Path
  echo "🖼️ Step 4: Find the Icon 🖼️"
  echo "Now, let's find an icon for your app (PNG or SVG format)."
  prompt_for_file "APP_ICON_PATH" "Please provide the path to the icon file: "

  # Step 5: Categories
  echo "🗂️ Step 5: Choose Categories 🗂️"
  echo "Lastly, pick some categories that best describe your app (separated by semicolons)."
  read -p "Categories [$DEFAULT_CATEGORIES]: " input_app_categories
  APP_CATEGORIES="${input_app_categories:-$DEFAULT_CATEGORIES}"

  while [[ -z "$APP_CATEGORIES" ]]; do
    echo "Error: Categories can't be empty. Please try again."
    log "ERROR" "Categories cannot be empty."
    read -p "Please enter categories for your app (separated by semicolons): " APP_CATEGORIES
  done

  # Save configuration
  save_config

  # Determine the location to save the desktop entry file
  USER_DESKTOP_ENTRY_DIR="$HOME/.local/share/applications"
  SYSTEM_DESKTOP_ENTRY_DIR="/usr/share/applications"

  if [ -w "$SYSTEM_DESKTOP_ENTRY_DIR" ]; then
    DESKTOP_ENTRY_PATH="$SYSTEM_DESKTOP_ENTRY_DIR/$APP_NAME.desktop"
    log "INFO" "System-wide installation."
  else
    DESKTOP_ENTRY_PATH="$USER_DESKTOP_ENTRY_DIR/$APP_NAME.desktop"
    log "INFO" "User-specific installation."
  fi

  # Create the desktop entry file
  echo "🔨 Creating the Desktop Entry File... 🔨"
  log "INFO" "Creating the desktop entry file..."

  DESKTOP_ENTRY="[Desktop Entry]
Version=1.0
Type=Application
Name=$APP_NAME
Comment=$APP_DESCRIPTION
Exec=\"$APP_IMAGE_PATH\" %U
Icon=$APP_ICON_PATH
Categories=$APP_CATEGORIES
"

  echo "$DESKTOP_ENTRY" > "$DESKTOP_ENTRY_PATH"

  # Set permissions if saved in the system-wide directory
  if [ "$DESKTOP_ENTRY_PATH" = "$SYSTEM_DESKTOP_ENTRY_DIR/$APP_NAME.desktop" ]; then
    sudo chmod +r "$DESKTOP_ENTRY_PATH"
  fi

  echo "🌟 Desktop entry file created and installed successfully! 🌟"
  log "INFO" "Desktop entry file created and installed successfully."

  # Update the desktop database
  if command -v update-desktop-database &>/dev/null; then
    echo "💾 Updating the Desktop Database... 💾"
    log "INFO" "Updating the desktop database..."
    sudo update-desktop-database
    echo "🎉 Desktop database updated! 🎉"
    log "INFO" "Desktop database updated."
  else
    echo "⚠️ Warning: 'update-desktop-database' command not found. You may need to manually refresh your desktop environment."
    log "WARNING" "'update-desktop-database' command not found."
  fi

  echo "🎉 Congratulations! Integration of $APP_NAME with the desktop is complete! 🎉"
  echo "You should now be able to find your app in the application menu."
  log "INFO" "Integration of $APP_NAME with the desktop is complete."
}

# Function to modify an existing AppImage integration
# Function to modify an existing AppImage integration
modify_appimage() {
  echo "🌟 Integration Wizard - Modify Existing AppImage 🌟"
  echo "Currently integrated AppImages:"
  ls -1 "$USER_DESKTOP_ENTRY_DIR"/*.desktop

  # Step 1: Choose AppImage to Modify
  read -p "Please enter the name of the AppImage you want to modify (without '.desktop' extension): " APP_NAME

  # Check if the specified AppImage exists
  if [ ! -f "$USER_DESKTOP_ENTRY_DIR/$APP_NAME.desktop" ]; then
    echo "Error: The specified AppImage does not exist. Please check the name and try again."
    log "ERROR" "The specified AppImage does not exist: $USER_DESKTOP_ENTRY_DIR/$APP_NAME.desktop"
    return
  fi

  # Load configuration for the specified AppImage
  CONFIG_FILE="$USER_DESKTOP_ENTRY_DIR/$APP_NAME.desktop"

  # Ensure that the configuration file exists
  if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
  else
    echo "Error: Configuration file for $APP_NAME not found. Cannot modify the integration."
    log "ERROR" "Configuration file not found: $CONFIG_FILE"
    return
  fi

  # Step 2: Modify App Information
  echo "📝 Step 2: Modify App Information 📝"

  # App Name
  read -p "App Name [$APP_NAME]: " input_app_name
  APP_NAME="${input_app_name:-$APP_NAME}"

  # App Description
  read -p "App Description [$APP_DESCRIPTION]: " input_app_description
  APP_DESCRIPTION="${input_app_description:-$APP_DESCRIPTION}"

  # AppImage Path
  prompt_for_file "APP_IMAGE_PATH" "AppImage Path [$APP_IMAGE_PATH]: "

  # Icon File Path
  prompt_for_file "APP_ICON_PATH" "Icon File Path [$APP_ICON_PATH]: "

  # Categories
  read -p "Categories [$APP_CATEGORIES]: " input_app_categories
  APP_CATEGORIES="${input_app_categories:-$APP_CATEGORIES}"

  # Save configuration
  save_config

  # Update the desktop entry file
  echo "🔨 Updating the Desktop Entry File... 🔨"
  log "INFO" "Updating the desktop entry file..."

  DESKTOP_ENTRY="[Desktop Entry]
Version=1.0
Type=Application
Name=$APP_NAME
Comment=$APP_DESCRIPTION
Exec=\"$APP_IMAGE_PATH\" %U
Icon=$APP_ICON_PATH
Categories=$APP_CATEGORIES
"

  echo "$DESKTOP_ENTRY" > "$CONFIG_FILE"

  echo "🌟 Desktop entry file updated successfully! 🌟"
  log "INFO" "Desktop entry file updated successfully."

  # Update the desktop database
  if command -v update-desktop-database &>/dev/null; then
    echo "💾 Updating the Desktop Database... 💾"
    log "INFO" "Updating the desktop database..."
    sudo update-desktop-database
    echo "🎉 Desktop database updated! 🎉"
    log "INFO" "Desktop database updated."
  else
    echo "⚠️ Warning: 'update-desktop-database' command not found. You may need to manually refresh your desktop environment."
    log "WARNING" "'update-desktop-database' command not found."
  fi

  echo "🎉 Congratulations! Modification of $APP_NAME with the desktop is complete! 🎉"
  log "INFO" "Modification of $APP_NAME with the desktop is complete."
}

# ... (the rest of the script remains unchanged)


# Function to delete an existing AppImage integration
delete_appimage() {
  echo "🌟 Integration Wizard - Delete AppImage 🌟"
  echo "Currently integrated AppImages:"
  ls -1 "$USER_DESKTOP_ENTRY_DIR"/*.desktop

  # Step 1: Choose AppImage to Delete
  read -p "Please enter the name of the AppImage you want to delete (without '.desktop' extension): " APP_NAME

  # Check if the specified AppImage exists
  if [ ! -f "$USER_DESKTOP_ENTRY_DIR/$APP_NAME.desktop" ]; then
    echo "Error: The specified AppImage does not exist. Please check the name and try again."
    log "ERROR" "The specified AppImage does not exist: $USER_DESKTOP_ENTRY_DIR/$APP_NAME.desktop"
    return
  fi

  # Delete the desktop entry file
  echo "🗑️ Deleting the Desktop Entry File... 🗑️"
  log "INFO" "Deleting the desktop entry file..."
  rm "$USER_DESKTOP_ENTRY_DIR/$APP_NAME.desktop"

  echo "🎉 $APP_NAME has been successfully uninstalled and removed from the desktop! 🎉"
  log "INFO" "$APP_NAME has been successfully uninstalled and removed from the desktop."

  # Update the desktop database (suppress error message if command is not found)
  if command -v update-desktop-database &>/dev/null; then
    echo "💾 Updating the Desktop Database... 💾"
    log "INFO" "Updating the desktop database..."
    update_desktop_database "$USER_DESKTOP_ENTRY_DIR"
    echo "🎉 Desktop database updated! 🎉"
    log "INFO" "Desktop database updated."
  else
    echo "⚠️ Warning: 'update-desktop-database' command not found. You may need to manually refresh your desktop environment."
    log "WARNING" "'update-desktop-database' command not found."
  fi
}


# Function to display the main menu
display_menu() {
  echo "🌟 Welcome to the AppImage Integration Wizard! 🌟"
  echo "Please choose an option:"
  echo "1. Integrate a New AppImage"
  echo "2. Modify an Existing AppImage"
  echo "3. Delete an Existing AppImage"
  echo "4. Exit"
}

# Main program loop
while true; do
  display_menu
  read -p "Enter your choice (1/2/3/4): " choice

  case "$choice" in
    1)
      integrate_appimage
      ;;
    2)
      modify_appimage
      ;;
    3)
      delete_appimage
      ;;
    4)
      echo "👋 Thank you for using the AppImage Integration Wizard! Goodbye! 👋"
      break
      ;;
    *)
      echo "Error: Invalid input. Please choose a valid option (1/2/3/4)."
      ;;
  esac
done
