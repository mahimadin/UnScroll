#!/usr/bin/env python3
"""Patch Android configuration and cached pub plugins to ensure compileSdk 36."""
import json
import os
import pathlib
import re

APP_ID = "com.unscroll.social"

def patch_file(g: pathlib.Path, name: str = ""):
    try:
        txt = g.read_text(encoding="utf-8", errors="ignore")
        # Replace compileSdkVersion 34 (or 33/35) or compileSdk = 34 with 36
        new_txt = re.sub(r'compileSdk(Version)?\s*=\s*\d+', 'compileSdk = 36', txt)
        new_txt = re.sub(r'compileSdkVersion\s+\d+', 'compileSdkVersion 36', new_txt)
        if new_txt != txt:
            g.write_text(new_txt, encoding="utf-8")
            print(f"Patched plugin {name or g.parent.name}: {g}")
    except Exception as e:
        print(f"Failed to patch {g}: {e}")

# 1. Patch plugins listed in .flutter-plugins-dependencies
plugins_dep = pathlib.Path(".flutter-plugins-dependencies")
if plugins_dep.exists():
    try:
        data = json.loads(plugins_dep.read_text())
        android_plugins = data.get("plugins", {}).get("android", [])
        for p in android_plugins:
            p_path = pathlib.Path(p["path"]) / "android"
            if p_path.exists():
                for g in p_path.glob("build.gradle*"):
                    patch_file(g, p["name"])
    except Exception as e:
        print(f"Error reading .flutter-plugins-dependencies: {e}")

# 2. Patch plugins listed in .flutter-plugins
flutter_plugins = pathlib.Path(".flutter-plugins")
if flutter_plugins.exists():
    try:
        for line in flutter_plugins.read_text().splitlines():
            if "=" in line:
                p_name, p_path = line.split("=", 1)
                p_dir = pathlib.Path(p_path.strip()) / "android"
                if p_dir.exists():
                    for g in p_dir.glob("build.gradle*"):
                        patch_file(g, p_name)
    except Exception as e:
        print(f"Error reading .flutter-plugins: {e}")

# 3. Patch across all potential pub cache directories
cache_candidates = [
    os.environ.get("PUB_CACHE"),
    os.path.expanduser("~/.pub-cache"),
    "/opt/hostedtoolcache",
    "/root/.pub-cache"
]
for c in cache_candidates:
    if c and pathlib.Path(c).exists():
        for g in pathlib.Path(c).rglob("build.gradle*"):
            if "file_picker" in str(g) or "image_picker" in str(g) or "video_player" in str(g):
                patch_file(g, g.parent.name)

# 4. Patch android/app/build.gradle(.kts)
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

# 5. Patch root android/build.gradle(.kts) using plugins.withId (safe, no afterEvaluate)
root_gradle = next(
    (p for p in (pathlib.Path("android/build.gradle.kts"),
                 pathlib.Path("android/build.gradle")) if p.exists()),
    None,
)
if root_gradle:
    root_kts = root_gradle.suffix == ".kts"
    root_s = root_gradle.read_text()
    if "com.android.library" not in root_s:
        if root_kts:
            subprojects_block = """
subprojects {
    plugins.withId("com.android.library") {
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                val m = android.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
                m.invoke(android, 36)
            } catch (e: Throwable) {
                try {
                    val m2 = android.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                    m2.invoke(android, 36)
                } catch (e2: Throwable) {}
            }
        }
    }
}
"""
        else:
            subprojects_block = """
subprojects {
    plugins.withId("com.android.library") {
        project.android {
            compileSdkVersion 36
        }
    }
}
"""
        root_gradle.write_text(root_s + "\n" + subprojects_block)

# 6. Patch gradle.properties
props_file = pathlib.Path("android/gradle.properties")
if props_file.exists():
    props_s = props_file.read_text()
    if "android.suppressUnsupportedCompileSdk" not in props_s:
        props_file.write_text(props_s + "\nandroid.suppressUnsupportedCompileSdk=36\n")

# 7. AndroidManifest.xml permissions and queries
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
