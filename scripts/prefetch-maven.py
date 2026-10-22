"""Download one Maven Central artifact with published checksum into Gradle file store.

Used only when a transient Java TLS error interrupts the official build download.
Python still validates HTTPS certificates; no trust or TLS settings are relaxed.
"""
from pathlib import Path
import hashlib
import urllib.request
import sys
import re
from concurrent.futures import ThreadPoolExecutor

def fetch(coordinates):
    group, artifact, version = coordinates
    filename = f'{artifact}-{version}.jar'
    url = f'https://repo.maven.apache.org/maven2/{group.replace(".", "/")}/{artifact}/{version}/{filename}'
    payload = urllib.request.urlopen(url, timeout=60).read()
    expected = urllib.request.urlopen(url + '.sha1', timeout=30).read().decode().strip().split()[0]
    sha1 = hashlib.sha1(payload).hexdigest()
    if sha1 != expected: raise ValueError('Artifact checksum mismatch')
    target = Path(__file__).resolve().parents[1] / '.tooling/gradle-cache/caches/modules-2/files-2.1' / group / artifact / version / sha1 / filename
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(payload)
    print(filename, 'verified SHA256', hashlib.sha256(payload).hexdigest(),flush=True)

if sys.argv[1]=='--from-log':
    content=Path(sys.argv[2]).read_text(encoding='utf-8',errors='replace')
    coordinates=sorted(set(re.findall(r'Could not download [^\s]+\.jar \(([^:()]+):([^:()]+):([^:()]+)\)',content)))
    print('Official Maven Central artifacts',len(coordinates),flush=True)
    with ThreadPoolExecutor(max_workers=4) as pool:list(pool.map(fetch,coordinates))
else:fetch(sys.argv[1:4])
