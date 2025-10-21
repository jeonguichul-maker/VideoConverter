#!/system/bin/sh
APK_SRC=$(find /sdcard/AIDE/Projects/VideoConverter/app/build -type f -name "*.apk" | tail -n 1)
APK_DST="/sdcard/Download/VideoConverter_final.apk"
if [ -n "$APK_SRC" ]; then
  mv "$APK_SRC" "$APK_DST"
  echo "APK moved to: $APK_DST"
else
  echo "No APK found."
fi
