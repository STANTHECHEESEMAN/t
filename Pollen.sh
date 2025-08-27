#!/bin/bash

if [ $(id -u) -ne 0 ]; then
    echo "Please run this script as root. You can do so by using 'sudo su'."
    exit
fi

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


sleep 1

while true; do
    echo ""
    echo "Please choose an option:"
    echo "  1) Apply policies temporarily (reverts on reboot)"
    echo "  2) Apply policies permanently (requires RootFS disabled)"
    echo "  3) Disable RootFS verification (DANGEROUS, NOT RECOMMENDED)"
    echo "  4) Fetch latest policies from repository"
    echo "  5) Exit"
    echo ""
    read -p "Enter your choice [1-5]: " choice

    case $choice in
        1)
            echo "Applying policies temporarily..."
            mkdir -p /tmp/overlay/etc/opt/chrome/policies/managed
            cp Policies.json /tmp/overlay/etc/opt/chrome/policies/managed/policy.json
            if [ $? -ne 0 ]; then
                echo "Failed to copy policies. Make sure Policies.json is in the same directory."
                exit 1
            fi
            cp -a -L /etc/* /tmp/overlay/etc 2> /dev/null
            mount --bind /tmp/overlay/etc /etc
            echo ""
            echo "Pollen has been successfully applied temporarily!"
            echo "Changes will be reverted on reboot."
            break
            ;;
        2)
            echo "This option requires RootFS verification to be disabled."
            echo "If it is not disabled, this will likely not work."
            read -p "Do you want to continue? (y/N): " confirm
            if [[ "$confirm" =~ ^[yY](es)?$ ]]; then
                echo "Applying policies permanently..."
                mkdir -p /etc/opt/chrome/policies/managed
                cp Policies.json /etc/opt/chrome/policies/managed/pollen.json
                if [ $? -ne 0 ]; then
                    echo "Failed to copy policies. Make sure Policies.json is in the same directory."
                    exit 1
                fi
                echo ""
                echo "Pollen has been successfully applied permanently!"
            else
                echo "Operation cancelled."
            fi
            break
            ;;
        3)
            echo "WARNING: This will disable RootFS verification on your device."
            echo "Disabling RootFS can cause your Chromebook to soft-brick if you re-enter verified mode."
            echo "It is HIGHLY recommended NOT to do this unless you know EXACTLY what you are doing."
            read -p "Are you absolutely sure you want to continue? (y/N): " confirm
            if [[ "$confirm" =~ ^[yY](es)?$ ]]; then
                echo "Disabling RootFS..."
                sudo /usr/share/vboot/bin/make_dev_ssd.sh -i /dev/mmcblk0 --remove_rootfs_verification --partitions 2
                sudo /usr/share/vboot/bin/make_dev_ssd.sh -i /dev/mmcblk0 --remove_rootfs_verification --partitions 4
                echo ""
                echo "RootFS has been disabled!"
            else
                echo "Operation cancelled."
            fi
            break
            ;;
        4)
            # IF YOU'RE FORKING, CHANGE THESE URLS, TALKING TO YOU MW
            echo "Fetching latest policies from https://github.com/blankuserrr/Pollen ..."
            curl -sL "https://raw.githubusercontent.com/blankuserrr/Pollen/main/Policies.json" -o "Policies.json"
            if [ $? -eq 0 ]; then
                echo "Policies.json has been updated successfully."
            else
                echo "Failed to fetch policies. Please check your internet connection."
            fi
            ;;
        5)
            echo "Exiting."
            exit 0
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
    esac
done
