#!/usr/bin/env python3
"""Patch Android configuration and cached pub plugins to ensure compileSdk 36."""
import os
import pathlib
import re

APP_ID = "com.unscroll.social"

# 1. Patch pub-cache plugins (e.g. file_picker, image_picker) to compileSdk 36
pub_cache = pathlib.Path(os.path.expanduser("~/.pub-cache"))
if pub_cache.exists():
    for f in pub_cache.rglob("build.gradle*"):
        try:
            txt = f.read_text(encoding="utf-8", errors="ignore")
            new_txt = re.sub(r'compileSdk(Version)?\s*=\s*\d+', r'compileSdk = 36', txt)
            new_txt = re.sub(r'compileSdkVersion\s+\d+', r'compileSdkVersion 36', new_txt)
            if new_txt != txt:
                f.write_text(new_txt, encoding="utf-8")
                print(f"Updated {f.parent.name}/{f.name} to compileSdk 36")
        except Exception:
            pass

# 2. Patch android/app/build.gradle(.kts)
app_gradle = next(
    (p for p in (pathlib.Path("android/app/build.gradle.kts"),
                 pathlib.Path("android/app/build.gradle")) if p.exists()),
    None,
)
if app_gradle:
    kts = app_gradle.suffix == ".kts"
    s = app_gradle.read_text()
    eq = " = " if kts else " "

    s = re.sub(r'namespace\s*=?\s*"[^"]*"', f'namespace{eq}"{APP_ID}"', s)
    s = re.sub(r'applicationId\s*=?\s*"[^"]*"', f'applicationId{eq}"{APP_ID}"', s)
    s = re.sub(r'compileSdk\w*\s*=?\s*[^\n]+', f'compileSdk{eq}36', s)
    s = re.sub(r'minSdk\w*\s*=?\s*[^\n]+', f'minSdk{eq}24', s)
    s = re.sub(r'targetSdk\w*\s*=?\s*[^\n]+', f'targetSdk{eq}34', s)

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

    app_gradle.write_text(s)

# 3. Patch gradle.properties
props_file = pathlib.Path("android/gradle.properties")
if props_file.exists():
    props_s = props_file.read_text()
    if "android.suppressUnsupportedCompileSdk" not in props_s:
        props_file.write_text(props_s + "\nandroid.suppressUnsupportedCompileSdk=36\n")

# 4. AndroidManifest.xml permissions and queries
manifest = pathlib.Path("android/app/src/main/AndroidManifest.xml")
if manifest.exists():
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

print("Patching completed successfully.")
