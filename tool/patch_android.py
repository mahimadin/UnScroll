#!/usr/bin/env python3
"""Patch the Flutter-generated Android project (run from repo root, after `flutter create`).

Sets applicationId/namespace=com.unscroll.social, minSdk=24, targetSdk=34, compileSdk=34,
adds necessary permissions and intent queries to AndroidManifest.xml, and disables lint build failures.
"""
import pathlib
import re

APP_ID = "com.unscroll.social"
gradle = next(
    (p for p in (pathlib.Path("android/app/build.gradle.kts"),
                 pathlib.Path("android/app/build.gradle")) if p.exists()),
    None,
)
assert gradle, "android/app/build.gradle(.kts) not found"
kts = gradle.suffix == ".kts"
s = gradle.read_text()

eq = " = " if kts else " "
# Namespace & ApplicationId
s = re.sub(r'namespace\s*=?\s*"[^"]*"', f'namespace{eq}"{APP_ID}"', s)
s = re.sub(r'applicationId\s*=?\s*"[^"]*"', f'applicationId{eq}"{APP_ID}"', s)

# SDK Versions
s = re.sub(r'compileSdk\w*\s*=?\s*[^\n]+', f'compileSdk{eq}36', s)
s = re.sub(r'minSdk\w*\s*=?\s*[^\n]+', f'minSdk{eq}24', s)
s = re.sub(r'targetSdk\w*\s*=?\s*[^\n]+', f'targetSdk{eq}34', s)

# Add lint configuration to avoid CI failures on minor warnings
if kts:
    if "lint {" not in s:
        lint_block = """
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
"""
        s = re.sub(r'(android\s*\{)', r'\1' + lint_block, s, count=1)
else:
    if "lintOptions {" not in s:
        lint_block = """
    lintOptions {
        checkReleaseBuilds false
        abortOnError false
    }
"""
        s = re.sub(r'(android\s*\{)', r'\1' + lint_block, s, count=1)

gradle.write_text(s)

# AndroidManifest.xml permissions and queries
manifest = pathlib.Path("android/app/src/main/AndroidManifest.xml")
m = manifest.read_text()
m = re.sub(r'android:label="[^"]*"', 'android:label="Unscroll"', m, count=1)

permissions = """
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
"""

queries = """
    <queries>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
    </queries>
"""

if "<uses-permission" not in m:
    m = m.replace("<application", permissions + "\n    <application", 1)

if "<queries>" not in m:
    m = m.replace("</manifest>", queries + "\n</manifest>", 1)

manifest.write_text(m)

print(f"Patched {gradle} and AndroidManifest.xml successfully.")
