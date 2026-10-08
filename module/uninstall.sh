#!/system/bin/sh
# Keeps /data/adb/tailscale (node identity + settings) so a reinstall stays logged in.
# To wipe it: rm -rf /data/adb/tailscale
/data/adb/modules/android-tailscaled/system/bin/tailscaled.service stop
