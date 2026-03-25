#!/system/bin/sh

KEXEC_SRC="$MODPATH/kexec-bin/$ARCH/kexec"

if [ ! -f "$KEXEC_SRC" ]; then
    abort "Unsupported architecture: $ARCH"
fi

ui_print "- Installing kexec for $ARCH"
mkdir -p "$MODPATH/system/bin"
cp "$KEXEC_SRC" "$MODPATH/system/bin/kexec"
set_perm "$MODPATH/system/bin/kexec" 0 0 0755

# Remove arch binaries not needed at runtime
rm -rf "$MODPATH/kexec-bin"
