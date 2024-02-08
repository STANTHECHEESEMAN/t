#!/bin/bash

if [ $(id -u) -ne 0 ]; then
    echo "Run this script as root (sudo su)"
    exit
fi

echo "+##############################################+"
echo "# Welcome To Pollen!                           #"
echo "# The User Policy Editor                       #"
echo "# -------------------------------------------- #"
echo "# Developers:                                  #"
echo "# - OlyB                                       #"
echo "# - Rafflesia                                  #"
echo "# - Scaratek                                   #"
echo "# - r58Playz                                   #"
echo "# - Honkychunkymonkey - Additional Changes     #"
echo "+##############################################+"
echo "May Ultrablue Rest in Peace, o7"

sleep 1

# Check if the policy.json already exists and back it up as old.policies.json
POLICY_FILE="/etc/opt/chrome/policies/managed/policy.json"
BACKUP_DIR="/home/chronos/user/Downloads"
if [ -f "$POLICY_FILE" ]; then
    echo "Backing up existing policy.json to $BACKUP_DIR/old.policies.json"
    cp "$POLICY_FILE" "$BACKUP_DIR/old.policies.json"
fi

mkdir -p /tmp/overlay/etc/opt/chrome/policies/managed
echo '{
  "URLBlocklist": [],
  "SystemFeaturesDisableList": [],
  "EditBookmarksEnabled": true,
  "ChromeOsMultiProfileUserBehavior": "unrestricted",
  "DeveloperToolsAvailability": 1,
  "DefaultPopupsSetting": 1,
  "AllowDeletingBrowserHistory": true,
  "AllowDinosaurEasterEgg": true,
  "IncognitoModeAvailability": 0,
  "AllowScreenLock": true,
  "ExtensionAllowedTypes": null,
  "ExtensionInstallAllowlist": null,
  "ExtensionInstallBlocklist": null,
  "PasswordManagerEnabled": "true",
  "TaskManagerEndProcessEnabled": "true",
  "UptimeLimit": "null",
  "SystemTerminalSshAllowed": "true",
  "SystemTimezone": "",
  "IsolatedAppsDeveloperModeAllowed": "true",
  "ForceGoogleSafeSearch": "false",
  "ForceYouTubeRestrict": "0",
  "EasyUnlockAllowed": "true",
  "DisableSafeBrowsingProceedAnyway": "false",
  "DeviceAllowNewUsers": "true",
  "DevicePowerAdaptiveChargingEnabled": "true",
  "DeviceGuestModeEnabled": "true",
  "DeviceUnaffiliatedCrostiniAllowed": "true",
  "VirtualMachinesAllowed": "true",
  "CrostiniAllowed": "true",
  "DefaultCookiesSetting": "1",
  "VmManagementCliAllowed": "true",
  "WifiSyncAndroidAllowed": "true",
  "DeveloperToolsDisabled": "false",
  "DeveloperToolsAvailability": "1",
  "DeviceBlockDevmode": "false",
  "UserBorealisAllowed": "true",
  "InstantTetheringAllowed": "true",
  "NearbyShareAllowed": "true",
  "PinnedLauncherApps": "null",
  "PrintingEnabled": "true",
  "SmartLockSigninAllowed": "true",
  "PhoneHubAllowed": "true",
  "LacrosAvailability": "user_choice",
  "WallpaperImage": null,
  "ArcPolicy": {
    "playStoreMode": "ENABLED",
    "installType": "FORCE_INSTALLED",
    "playEmmApiInstallDisabled": false,
    "dpsInteractionsDisabled": false
  },
  "DnsOverHttpsMode": "automatic",
  "BrowserLabsEnabled": "true",
  "ChromeOsReleaseChannelDelegated": "true",
  "WallpaperImage": "null",
  "SafeSitesFilterBehavior": "0",
  "SafeBrowsingProtectionLevel": "0",
  "DownloadRestrictions": "0",
  "ProxyMode": "system",
  "ProxyServerMode": "system",
  "NetworkThrottlingEnabled": "false",
  "NetworkPredictionOptions": "0",
  "AllowedDomainsForApps": "",
  "DeviceUserAllowlist": "",
  "BlockThirdPartyCookies": "",
  "ChromeOsReleaseChannel": "",
  "FastPairEnabled": "true",
}' > /tmp/overlay/etc/opt/chrome/policies/managed/policy.json
cp -a -L /etc/* /tmp/overlay/etc 2> /dev/null
mount --bind /tmp/overlay/etc /etc

echo ""
echo "Pollen - Beta 0.1.1 has been successfully applied!"
