#!/bin/bash
BASE="/sdcard/AIDE/Projects/VideoConverter"

# 초기화
mkdir -p "$BASE/src"
mkdir -p "$BASE/res/layout"
mkdir -p "$BASE/res/values"
mkdir -p "$BASE/libs"
mkdir -p "$BASE/bin"
mkdir -p "$BASE/gen"

# AndroidManifest 이동
if [ -f "$BASE/app/src/main/AndroidManifest.xml" ]; then
    cp "$BASE/app/src/main/AndroidManifest.xml" "$BASE/AndroidManifest.xml"
fi

# 소스 이동
PKG_DIR="$BASE/src/com/example/videoconverter"
mkdir -p "$PKG_DIR"
if [ -f "$BASE/app/src/main/java/com/example/videoconverter/MainActivity.kt" ]; then
    cp "$BASE/app/src/main/java/com/example/videoconverter/MainActivity.kt" "$PKG_DIR/"
fi

# 리소스 이동
cp -r "$BASE/app/src/main/res/"* "$BASE/res/" 2>/dev/null

# 필수 구성 파일 생성
cat > "$BASE/project.properties" <<'PROP'
target=android-34
android.library=false
PROP

cat > "$BASE/build.gradle" <<'GRAD'
apply plugin: 'com.android.application'

android {
    compileSdkVersion 34
    defaultConfig {
        applicationId "com.example.videoconverter"
        minSdkVersion 21
        targetSdkVersion 34
        versionCode 1
        versionName "1.0"
    }
}

dependencies {
    implementation fileTree(dir: "libs", include: ["*.jar"])
}
GRAD

cat > "$BASE/settings.gradle" <<'SET'
rootProject.name = "VideoConverter"
include ':app'
SET

cat > "$BASE/README.txt" <<'TXT'
AIDE Classic project layout.
All sources now directly under /src and /res.
If build button remains disabled, reopen AIDE, tap "Open existing project" -> select /VideoConverter.
TXT

echo "✅ AIDE Classic 구조 변환 완료."
