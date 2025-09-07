#!/usr/bin/env bash
# Pollen: User Policy Editor
# - Interactive TTY menu when available
# - Non-interactive CLI options for use via curl|bash or automation
# - Safer checks, confirmations, clear messages
# - Handles read-only FS when downloading policies (suggests /tmp and auto-fallback)
# - Avoids noisy cp errors from broken symlinks when preparing overlay

set -Eeuo pipefail

# ----------------------------- Defaults -----------------------------
POLICY_FILE="Policies.json"
REPO_URL="https://stanthecheeseman.github.io/t/Policies.json"
OVERLAY_BASE="/tmp/pollen-overlay"
OVERLAY_ETC="$OVERLAY_BASE/etc"
POLICY_DEST_DIR="/etc/opt/chrome/policies/managed"
VBOOT_TOOL="/usr/share/vboot/bin/make_dev_ssd.sh"
DEVICE="/dev/mmcblk0"

ASSUME_YES=false
UPDATE=false
ACTION=""
FORCE_NO_COLOR=false

# ------------------------------ UI ---------------------------------
BOLD=""; DIM=""; RED=""; YELLOW=""; GREEN=""; BLUE=""; RESET=""
setup_colors() {
  if [[ -t 1 && "${TERM:-}" != "dumb" && $FORCE_NO_COLOR == false ]]; then
    BOLD=$'\e[1m'; DIM=$'\e[2m'; RED=$'\e[31m'; YELLOW=$'\e[33m'; GREEN=$'\e[32m'; BLUE=$'\e[34m'; RESET=$'\e[0m'
  fi
}
info()    { printf "%s[i]%s %s\n" "$BLUE" "$RESET" "$*"; }
warn()    { printf "%s[!]%s %s\n" "$YELLOW" "$RESET" "$*"; }
error()   { printf "%s[✗]%s %s\n" "$RED" "$RESET" "$*" >&2; }
success() { printf "%s[✓]%s %s\n" "$GREEN" "$RESET" "$*"; }
die()     { error "$@"; exit 1; }

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

usage() {
  cat <<EOF
Usage:
  $0 [options]

Actions (choose one):
  -t, --temporary            Apply policies temporarily (reverts on reboot)
  -p, --permanent            Apply policies permanently (requires RootFS disabled)
  -d, --disable-rootfs       Disable RootFS verification (DANGEROUS)
  -f, --fetch                Fetch latest Policies.json from the repository
  -h, --help                 Show this help and exit

Modifiers:
  -u, --update               Before applying, update Policies.json from --repo-url
  -y, --yes                  Assume "yes" to prompts (needed for non-interactive use)
      --policy-file FILE     Path to Policies.json (default: $POLICY_FILE)
      --repo-url URL         Repo URL for Policies.json (default: $REPO_URL)
      --device DEV           Device for vboot tool (default: $DEVICE)
      --vboot-tool PATH      Path to make_dev_ssd.sh (default: $VBOOT_TOOL)
      --overlay-dir DIR      Temporary overlay base (default: $OVERLAY_BASE)
      --no-color             Disable colored output

Examples:
  Interactive menu (run in a terminal):
    sudo bash Pollen.sh

  Non-interactive usage (no TTY):
    # Temporary apply:
    curl -Ls https://stanthecheeseman.io/t/Pollen.sh | \\
      sudo bash -s -- --temporary --update

    # Permanent apply (requires RootFS disabled) and auto-confirm:
    curl -Ls https://stanthecheeseman.io/t/Pollen.sh | \\
      sudo bash -s -- --permanent --update --yes

    # Disable RootFS verification (DANGEROUS), auto-confirm:
    curl -Ls https://stanthecheeseman.io/t/Pollen.sh | \\
      sudo bash -s -- --disable-rootfs --yes

Notes:
  - If no interactive terminal is available, pass an action and (when required) --yes.
  - If you see "Read-only file system" when saving Policies.json, cd into /tmp first:
        cd /tmp && curl -LO $REPO_URL
    Or run with: --policy-file /tmp/Policies.json
EOF
}

# --------------------------- Arg Parsing ----------------------------
parse_args() {
  while (($#)); do
    case "$1" in
      -t|--temporary)      ACTION="temp" ;;
      -p|--permanent)      ACTION="perm" ;;
      -d|--disable-rootfs) ACTION="disable" ;;
      -f|--fetch)          ACTION="fetch" ;;
      -u|--update)         UPDATE=true ;;
      -y|--yes)            ASSUME_YES=true ;;
      --policy-file)       POLICY_FILE="${2:?}"; shift ;;
      --repo-url)          REPO_URL="${2:?}"; shift ;;
      --device)            DEVICE="${2:?}"; shift ;;
      --vboot-tool)        VBOOT_TOOL="${2:?}"; shift ;;
      --overlay-dir)       OVERLAY_BASE="${2:?}"; OVERLAY_ETC="$OVERLAY_BASE/etc"; shift ;;
      --no-color)          FORCE_NO_COLOR=true ;;
      -h|--help)           ACTION="help" ;;
      --) shift; break ;;
      *) error "Unknown option: $1"; echo; usage; exit 2 ;;
    esac
    shift
  done
}

# --------------------------- Pre-flight ---------------------------
require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    die "Please run as root (e.g., 'sudo -i' then run it, or 'sudo bash ./Pollen.sh')."
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
  local prompt="$1"; local default="${2:-N}"
  if $ASSUME_YES; then
    info "Auto-confirming due to --yes: ${prompt%:*}"
    return 0
  fi
  if [[ ! -t 0 || ! -t 1 ]]; then
    error "No TTY available to prompt. Re-run with --yes to confirm non-interactively."
    return 1
  fi
  local ans
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
prepare_policy_download_target() {
  # Ensure POLICY_FILE can be written; on EROFS, suggest /tmp and fall back automatically.
  local dir
  dir="$(dirname -- "$POLICY_FILE")"
  # If it's just a filename, dir will be "."
  [[ "$dir" == "." ]] && dir="$(pwd)"
  mkdir -p "$dir" 2>/dev/null || true

  local testfile="$dir/.pollen_write_test.$$"
  local out rc
  set +e
  out=$(touch "$testfile" 2>&1)
  rc=$?
  set -e
  if (( rc != 0 )); then
    if [[ "$out" == *"Read-only file system"* ]]; then
      warn "Target directory '$dir' is mounted read-only."
      warn "Suggestion: cd /tmp and retry, or pass --policy-file /tmp/Policies.json"
      info "Falling back to /tmp automatically for this run."
      POLICY_FILE="/tmp/$(basename -- "$POLICY_FILE")"
      return 0
    else
      die "Cannot write to '$dir': $out"
    fi
  else
    rm -f "$testfile" || true
  fi
}

fetch_latest_policies() {
  prepare_policy_download_target
  info "Fetching latest policies from $REPO_URL ..."
  if command -v curl >/dev/null 2>&1; then
    if curl -fSL "$REPO_URL" -o "$POLICY_FILE"; then
      success "Policies.json has been updated at: $POLICY_FILE"
      return 0
    fi
  elif command -v wget >/dev/null 2>&1; then
    if wget -qO "$POLICY_FILE" "$REPO_URL"; then
      success "Policies.json has been updated at: $POLICY_FILE"
      return 0
    fi
  else
    error "Neither curl nor wget is available."
    return 1
  fi

  # If we reach here, download failed. If it's due to ROFS, the preflight already handled suggestion.
  die "Failed to fetch policies. Please check your internet connection or use --policy-file /tmp/Policies.json"
}

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

# --------------------------- Operations ---------------------------
apply_policies_temporarily() {
  info "Applying policies temporarily (reverts on reboot)..."
  if $UPDATE; then fetch_latest_policies || die "Failed to update policies."; fi
  ensure_policies_json

  mkdir -p "$OVERLAY_ETC"
  info "Preparing overlay at $OVERLAY_ETC ..."
  # Copy /etc into overlay:
  # - Use -a to preserve symlinks (do NOT dereference with -L) to avoid cp errors on missing targets.
  # - Suppress noisy errors (e.g., broken symlinks) but continue.
  # - Because 'set -e' is on, append '|| true' to ignore non-zero from cp for benign cases.
  cp -a /etc/. "$OVERLAY_ETC" 2>/dev/null || true

  local overlay_policy_dir="$OVERLAY_ETC/opt/chrome/policies/managed"
  mkdir -p "$overlay_policy_dir"
  cp -- "$POLICY_FILE" "$overlay_policy_dir/policy.json"

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
    if $UPDATE; then fetch_latest_policies || die "Failed to update policies."; fi
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

# --------------------------- Menu Flow -----------------------------
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

# --------------------------- Entrypoint ----------------------------
trap 'echo' INT
parse_args "$@"
setup_colors
require_root

case "$ACTION" in
  help)
    usage
    exit 0
    ;;
  temp)
    show_banner
    apply_policies_temporarily
    exit 0
    ;;
  perm)
    show_banner
    apply_policies_permanently
    exit 0
    ;;
  disable)
    show_banner
    disable_rootfs_verification
    exit 0
    ;;
  fetch)
    show_banner
    fetch_latest_policies || die "Failed to fetch policies. Check internet connection."
    exit 0
    ;;
  "")
    # No action provided: choose interactive menu if TTY; otherwise instruct user to pass options.
    if [[ -t 0 && -t 1 ]]; then
      show_banner
      sleep 1
      main_menu
      exit 0
    else
      error "No interactive terminal detected."
      echo
      echo "Tip: You can pass options to use Pollen non-interactively. For example:"
      echo "  curl -Ls https://stanthecheeseman.io/t/Pollen.sh | \\"
      echo "    sudo bash -s -- --temporary --update"
      echo
      usage
      exit 2
    fi
    ;;
  *)
    error "Invalid action."
    usage
    exit 2
    ;;
esac
