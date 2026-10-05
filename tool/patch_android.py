#!/usr/bin/env python3
"""Patch the Flutter-generated Android project (run from repo root, after `flutter create`).

Sets applicationId/namespace=com.unscroll.social, minSdk=24, targetSdk=34, app label.
Works with both build.gradle (Groovy) and build.gradle.kts.
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
s = re.sub(r'namespace\s*=?\s*"[^"]*"', f'namespace = "{APP_ID}"' if kts else f'namespace "{APP_ID}"', s)
s = re.sub(r'applicationId\s*=?\s*"[^"]*"', f'applicationId{eq}"{APP_ID}"', s)
s = re.sub(r'minSdk(Version)?\s*=?\s*[^\n]+', f'minSdk{eq}24', s)
if re.search(r'targetSdk(Version)?\s*=?\s*[^\n]+', s):
    s = re.sub(r'targetSdk(Version)?\s*=?\s*[^\n]+', f'targetSdk{eq}34', s)
gradle.write_text(s)

manifest = pathlib.Path("android/app/src/main/AndroidManifest.xml")
m = manifest.read_text()
m = re.sub(r'android:label="[^"]*"', 'android:label="Unscroll"', m, count=1)
manifest.write_text(m)

print(f"Patched {gradle}:")
print("\n".join(l for l in s.splitlines() if re.search(r"namespace|applicationId|minSdk|targetSdk", l)))
