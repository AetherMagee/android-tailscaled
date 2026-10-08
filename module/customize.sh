#!/system/bin/sh
# shellcheck disable=SC2034
SKIPUNZIP=0

DATA=/data/adb/tailscale

[ "$ARCH" = arm64 ] || abort "! Only arm64 is supported (got $ARCH)"
[ "$BOOTMODE" = true ] || abort "! Install from Magisk, KernelSU or APatch, not recovery"

for m in magisk-tailscaled tailscaled; do
	if [ -d "/data/adb/modules/$m" ] && [ ! -f "/data/adb/modules/$m/disable" ]; then
		ui_print "! Another Tailscale module ($m) is enabled."
		ui_print "! Disable or remove it first; both use $DATA."
		abort
	fi
done

ln -sf tailscaled "$MODPATH/system/bin/tailscale"
set_perm_recursive "$MODPATH/system/bin" 0 0 0755 0755
set_perm_recursive "$MODPATH/scripts" 0 0 0755 0755
set_perm "$MODPATH/action.sh" 0 0 0755

mkdir -p "$DATA"
chmod 700 "$DATA"
if [ -f "$DATA/tailscaled.conf" ]; then
	ui_print "- Keeping existing $DATA/tailscaled.conf"
else
	mv "$MODPATH/tailscaled.conf" "$DATA/tailscaled.conf"
fi
rm -f "$MODPATH/tailscaled.conf"

# Start now from the staged module so it works before the first reboot.
OLD=/data/adb/modules/android-tailscaled/system/bin/tailscaled.service
[ -x "$OLD" ] && "$OLD" stop >/dev/null 2>&1
ui_print "- Starting tailscaled"
"$MODPATH/system/bin/tailscaled.service" start 2>&1 | while read -r l; do ui_print "  $l"; done

ui_print ""
ui_print "- Log in from the WebUI, or after a reboot: su -c 'tailscale up'"
ui_print "  (before rebooting: $MODPATH/system/bin/tailscale up)"
ui_print "- Service:  su -c 'tailscaled.service {start|stop|restart|status|log}'"
ui_print "- Settings: WebUI, or $DATA/tailscaled.conf"
