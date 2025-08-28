#!/usr/bin/env bash

set -Eeuo pipefail

# ----------------------------- Config -----------------------------
POLICY_FILE="Policies.json"
REPO_URL="https://raw.githubusercontent.com/blankuserrr/Pollen/main/Policies.json"
OVERLAY_BASE="/tmp/pollen-overlay"
OVERLAY_ETC="$OVERLAY_BASE/etc"
POLICY_DEST_DIR="/etc/opt/chrome/policies/managed"
VBOOT_TOOL="/usr/share/vboot/bin/make_dev_ssd.sh"
DEVICE="/dev/mmcblk0"

# ------------------------------ UI --------------------------------
if [[ -t 1 && "${TERM:-}" != "dumb" ]]; then
  BOLD=$'\e[1m'; DIM=$'\e[2m'; RED=$'\e[31m'; YELLOW=$'\e[33m'; GREEN=$'\e[32m'; BLUE=$'\e[34m'; RESET=$'\e[0m'
else
  BOLD=""; DIM=""; RED=""; YELLOW=""; GREEN=""; BLUE=""; RESET=""
fi

info()    { printf "%s[i]%s %s\n" "$BLUE" "$RESET" "$*"; }
warn()    { printf "%s[!]%s %s\n" "$YELLOW" "$RESET" "$*"; }
error()   { printf "%s[✗]%s %s\n" "$RED" "$RESET" "$*" >&2; }
success() { printf "%s[✓]%s %s\n" "$GREEN" "$RESET" "$*"; }
die()     { error "$@"; exit 1; }

# --------------------------- Pre-flight ---------------------------
require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    die "Please run this script as root (e.g., 'sudo -i' then run it, or 'sudo bash ./script.sh')."
  fi
}

require_tty() {
  if [[ ! -t 0 || ! -t 1 ]]; then
    die "This script requires an interactive terminal (stdin/stdout must be TTY)."
  fi
}

read_tty() {
  # Usage: read_tty "Prompt: " varname
  local prompt="$1"; local __varname="$2"; local REPLY
  if ! IFS= read -r -p "$prompt" REPLY < /dev/tty; then
    die "No input available (EOF). Exiting."
  fi
  printf -v "$__varname" "%s" "$REPLY"
}

ask_yes_no() {
  # Usage: ask_yes_no "Question (y/N): " default(N|Y)
  local prompt="$1"; local default="${2:-N}"; local ans
  while true; do
    read_tty "$prompt" ans
    ans="${ans:-$default}"
    case "$ans" in
      [yY]|[yY][eE][sS]) return 0 ;;
      [nN]|[nN][oO])     return 1 ;;
      *) echo "Please enter 'y' or 'n'." ;;
    esac
  done
}

prompt_choice() {
  local choice
  while true; do
    read_tty "Enter your choice [1-5]: " choice
    case "$choice" in
      1|2|3|4|5) printf "%s" "$choice"; return 0 ;;
      "") echo "No input provided. Please enter 1-5." ;;
      *)  echo "Invalid option. Please try again." ;;
    esac
  done
}

# --------------------------- Utilities ----------------------------
ensure_policies_json() {
  if [[ ! -f "$POLICY_FILE" ]]; then
    warn "'$POLICY_FILE' not found in: $(pwd)"
    if ask_yes_no "Download the latest Policies.json from the repository? (y/N): " "N"; then
      fetch_latest_policies || die "Failed to download policies."
    else
      die "'$POLICY_FILE' is required to apply policies."
    fi
  fi
}

fetch_latest_policies() {
  info "Fetching latest policies from $REPO_URL ..."
  if command -v curl >/dev/null 2>&1; then
    curl -fSL "$REPO_URL" -o "$POLICY_FILE" && success "Policies.json has been updated successfully." || return 1
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$POLICY_FILE" "$REPO_URL" && success "Policies.json has been updated successfully." || return 1
  else
    error "Neither curl nor wget is available."
    return 1
  fi
}

# --------------------------- Operations ---------------------------
apply_policies_temporarily() {
  info "Applying policies temporarily (reverts on reboot)..."
  ensure_policies_json

  mkdir -p "$OVERLAY_ETC"
  # Copy the entire /etc, preserving attributes and following symlinks; include dotfiles via '/.'.
  info "Preparing overlay at $OVERLAY_ETC ..."
  cp -a -L /etc/. "$OVERLAY_ETC"

  # Place the policy after copying the base tree to avoid accidental overwrites.
  local overlay_policy_dir="$OVERLAY_ETC/opt/chrome/policies/managed"
  mkdir -p "$overlay_policy_dir"
  cp -- "$POLICY_FILE" "$overlay_policy_dir/policy.json"

  # Bind-mount overlay over /etc
  if mount --bind "$OVERLAY_ETC" /etc; then
    success "Pollen has been successfully applied temporarily!"
    info "Changes will be reverted on reboot."
  else
    die "Failed to bind-mount overlay onto /etc."
  fi
}

apply_policies_permanently() {
  warn "This option requires RootFS verification to be disabled."
  warn "If it is not disabled, this will likely not work."
  if ask_yes_no "Do you want to continue? (y/N): " "N"; then
    ensure_policies_json
    info "Applying policies permanently..."
    mkdir -p "$POLICY_DEST_DIR"
    cp -- "$POLICY_FILE" "$POLICY_DEST_DIR/policy.json"
    success "Pollen has been successfully applied permanently!"
  else
    info "Operation cancelled."
  fi
}

disable_rootfs_verification() {
  warn "WARNING: This will disable RootFS verification on your device."
  warn "Disabling RootFS can cause your Chromebook to soft-brick if you re-enter verified mode."
  warn "It is HIGHLY recommended NOT to do this unless you know EXACTLY what you are doing."
  [[ -x "$VBOOT_TOOL" ]] || die "vboot tool not found at '$VBOOT_TOOL'. Are you on ChromeOS with developer tools installed?"

  if ask_yes_no "Are you absolutely sure you want to continue? (y/N): " "N"; then
    info "Disabling RootFS..."
    # Running both partitions as per original script
    if "$VBOOT_TOOL" -i "$DEVICE" --remove_rootfs_verification --partitions 2 &&
       "$VBOOT_TOOL" -i "$DEVICE" --remove_rootfs_verification --partitions 4; then
      success "RootFS verification has been disabled."
    else
      die "Failed to disable RootFS verification."
    fi
  else
    info "Operation cancelled."
  fi
}

# --------------------------- Main Menu ----------------------------
show_banner() {
  echo "+##############################################+"
  echo "| Welcome to Pollen!                           |"
  echo "| The User Policy Editor                       |"
  echo "| -------------------------------------------- |"
  echo "| Developers:                                  |"
  echo "| - OlyB                                       |"
  echo "| - Rafflesia                                  |"
  echo "| - r58Playz                                   |"
  echo "+##############################################+"
  echo "May Ultrablue rest in peace, o7."
  echo ""
}

main_menu() {
  while true; do
    echo ""
    echo "Please choose an option:"
    echo "  1) Apply policies temporarily (reverts on reboot)"
    echo "  2) Apply policies permanently (requires RootFS disabled)"
    echo "  3) Disable RootFS verification (DANGEROUS, NOT RECOMMENDED)"
    echo "  4) Fetch latest policies from repository"
    echo "  5) Exit"
    echo ""

    local choice
    choice="$(prompt_choice)"
    echo ""

    case "$choice" in
      1) apply_policies_temporarily; break ;;
      2) apply_policies_permanently; break ;;
      3) disable_rootfs_verification; break ;;
      4) fetch_latest_policies || error "Failed to fetch policies. Please check your internet connection." ;;
      5) info "Exiting."; exit 0 ;;
    esac
  done
}

# --------------------------- Entrypoint ---------------------------
trap 'echo' INT  # Format a clean newline on Ctrl-C
require_root
require_tty
show_banner
sleep 1
main_menu
