"""Install the exact Flutter NDK using Google's manifest and checksum.

Fallback for sdkmanager Java TLS errors; HTTPS certificate validation remains on.
"""
from pathlib import Path
import hashlib
import urllib.request
import xml.etree.ElementTree as ET
import zipfile
from download_tools import download

root = Path(__file__).resolve().parents[1] / '.tooling'
manifest = urllib.request.urlopen('https://dl.google.com/android/repository/repository2-1.xml',timeout=45).read()
doc = ET.fromstring(manifest)
package = next(p for p in doc.iter('remotePackage') if p.attrib.get('path') == 'ndk;28.2.13676358')
archive = next(a for a in package.findall('./archives/archive') if a.findtext('host-os') == 'windows')
relative = archive.findtext('./complete/url')
expected = archive.findtext('./complete/checksum')
print('Official package', relative, 'SHA1', expected, flush=True)
target_zip = root / 'ndk-r28c.zip'
download('https://dl.google.com/android/repository/' + relative,target_zip)
digest = hashlib.sha1()
with target_zip.open('rb') as source:
    while chunk := source.read(1024 * 1024): digest.update(chunk)
if digest.hexdigest() != expected: raise ValueError('NDK checksum mismatch')
target = root / 'android-sdk/ndk/28.2.13676358'
target.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(target_zip) as z:
    for info in z.infolist():
        if info.is_dir(): continue
        parts = info.filename.split('/')[1:]
        if '..' in parts: raise ValueError('Invalid archive path')
        dest = target.joinpath(*parts)
        dest.parent.mkdir(parents=True,exist_ok=True)
        dest.write_bytes(z.read(info))
print('NDK verified and extracted',flush=True)
