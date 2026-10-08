#!/system/bin/sh
# Root manager "Action" button: restart the daemon and show status.
/data/adb/modules/android-tailscaled/system/bin/tailscaled.service restart
echo
/data/adb/modules/android-tailscaled/system/bin/tailscale status
