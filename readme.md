![Pollen](/Pollen.png)

>[!IMPORTANT]
>Pollen is patched on ChromeOS R131 and above. <br />
<!--
>Patches: <br />
>https://chromiumdash.appspot.com/commit/313936b9fe8c343841378ffe5f33ad34de3bb3b7 <br />
>https://chromium-review.googlesource.com/c/chromium/src/+/5258257
-->

## What is it?
Pollen is a user policy editor that takes advantage of how policies are stored. On Linux systems, user policies can be modified by editing the file `/etc/opt/chrome/policies/managed`. ChromeOS works similarly where you can create a file named `Pollen.json` to change existing user policies.

Pollen **cannot** modify policies such as developer mode. If you want to modify **device policies**, check out [Lilac](https://github.com/mercuryworkshop/lilac).

## How do I use it?
> [!IMPORTANT]
>You must have developer mode enabled for Pollen to work!

If you notice that policy changes are not taking effect, visit `chrome://policy` and click "Reload Policies." If `chrome://policy` is blocked, enter VT-2 and run `restart ui`.

[//]: # (CHANGE THIS LINK IF MERGING/FORKING)
To use Pollen, enter the VT2 console by pressing `CTRL + ALT + F2`. You can login as `root` or `chronos` and then run the command: `curl -Ls https://raw.githubusercontent.com/blankuserrr/Pollen/refs/heads/main/Pollen.sh | bash` to execute the interactive Pollen script.

The script will provide options to:
1.  Apply policies temporarily (reverts on reboot).
2.  Apply policies permanently (requires RootFS disabled).
3.  Disable RootFS verification (DANGEROUS).
4.  Fetch the latest policies from the repository.
5.  Exit.

> [!WARNING]
> Disabling RootFS on your chromebook can cause it to soft-brick if you re-enter verified mode. It is not recommended unless you know what you are doing.

## Credits
- Discovery - Rafflesia
- Script Developer - OlyB
- Bug Fix - r58Playz
- Logo - Nitelite
- Readme - Scaratek
