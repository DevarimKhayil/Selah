#!/bin/bash
# Builds Selah for Android without Gradle, using the Ubuntu/Debian Android packages:
#   sudo apt-get install aapt apksigner zipalign dalvik-exchange android-sdk-platform-23 openjdk-17-jdk python3
# Signing: set SELAH_KEYSTORE and SELAH_KEYSTORE_PASS to your release key (alias "selah").
# Updates only install over the existing app when they are signed with the SAME key.
set -e
export JAVA_TOOL_OPTIONS=
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$HERE")"
A=/usr/lib/android-sdk/platforms/android-23/android.jar
cd "$HERE"
python3 "$ROOT/tools/build_android_data.py"
rm -rf build && mkdir -p build/gen build/obj
aapt package -f -m -J build/gen -M AndroidManifest.xml -S res -I $A
javac -nowarn -Xlint:none -source 8 -target 8 -bootclasspath $A -d build/obj build/gen/app/selah/R.java src/app/selah/*.java
dalvik-exchange --dex --output=build/classes.dex build/obj
aapt package -f -M AndroidManifest.xml -S res -A assets -I $A -F build/unsigned.apk
(cd build && zip -q unsigned.apk classes.dex)
zipalign -f 4 build/unsigned.apk build/aligned.apk
KS="${SELAH_KEYSTORE:-$HERE/selah-release.jks}"
PASS="${SELAH_KEYSTORE_PASS:-}"
if [ ! -f "$KS" ]; then
  echo "No keystore at $KS - creating a NEW one. Apps signed with it cannot update an app signed with your old key."
  PASS="${PASS:-change-me}"
  keytool -genkeypair -keystore "$KS" -storepass "$PASS" -keypass "$PASS" -alias selah -keyalg RSA -keysize 2048 -validity 20000 -dname "CN=Selah, O=Selah" >/dev/null
fi
[ -n "$PASS" ] || { echo "Set SELAH_KEYSTORE_PASS to the keystore password."; exit 1; }
apksigner sign --ks "$KS" --ks-pass "pass:$PASS" --out build/Selah.apk build/aligned.apk
apksigner verify build/Selah.apk && echo "Built $(pwd)/build/Selah.apk"
