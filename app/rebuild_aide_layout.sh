#!/bin/bash
BASE="/sdcard/AIDE/Projects/VideoConverter"
mkdir -p "$BASE/src/com/example/videoconverter"
mkdir -p "$BASE/res/layout" "$BASE/res/values" "$BASE/libs"
# src 및 리소스 복원
cp -r "$BASE/app/src/main/java/com/example/videoconverter/"* "$BASE/src/com/example/videoconverter/" 2>/dev/null
cp -r "$BASE/app/src/main/res/"* "$BASE/res/" 2>/dev/null
# 매니페스트 복사
cp "$BASE/app/src/main/AndroidManifest.xml" "$BASE/AndroidManifest.xml" 2>/dev/null
# gradle 무시, AIDE용 인식 파일 생성
echo "target=android-34" > "$BASE/project.properties"
echo "android.library=false" >> "$BASE/project.properties"
echo "sdk.dir=/data/data/com.aide.ui/files/android-sdk" > "$BASE/local.properties"
echo "ndk.dir=/data/data/com.aide.ui/files/ndk" >> "$BASE/local.properties"
echo "✅ 재구성 완료. AIDE 앱을 완전히 종료 후 다시 열어 ‘VideoConverter’ 선택." 
