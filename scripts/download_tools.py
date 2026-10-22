"""Project-local official tool downloads. No system PATH or registry changes."""
from pathlib import Path
import hashlib
import urllib.request
import zipfile
import time

root = Path(__file__).resolve().parents[1] / '.tooling'

def download(url, target, sha=None):
    print('Downloading', target.name, flush=True)
    for attempt in range(6):
        offset = target.stat().st_size if target.exists() else 0
        try:
            req = urllib.request.Request(url, headers={'Range': f'bytes={offset}-'} if offset else {})
            with urllib.request.urlopen(req, timeout=45) as response:
                mode = 'ab' if response.status == 206 else 'wb'
                with target.open(mode) as out:
                    while chunk := response.read(1024 * 1024):
                        out.write(chunk)
            break
        except (OSError, TimeoutError) as error:
            print('Retry', attempt + 1, type(error).__name__, flush=True)
            if attempt == 5: raise
            time.sleep(2)
    if sha and hashlib.sha256(target.read_bytes()).hexdigest() != sha:
        raise ValueError('Checksum mismatch: ' + target.name)
    print('Verified/downloaded', target.stat().st_size, flush=True)

if __name__ == '__main__':
    import sys
    if sys.argv[1] == 'android':
        archive = root / 'android-tools.zip'
        download('https://dl.google.com/android/repository/commandlinetools-win-15859902_latest.zip', archive,
                 '90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a')
        target = root / 'android-sdk' / 'cmdline-tools' / 'latest'
        target.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(archive) as z:
            for info in z.infolist():
                if info.is_dir(): continue
                name = info.filename.removeprefix('cmdline-tools/')
                dest = target / name
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(z.read(info))
        print('Android command line tools ready', flush=True)
    elif sys.argv[1] == 'jdk':
        archive = root / 'jdk17.zip'
        download('https://aka.ms/download-jdk/microsoft-jdk-17.0.16-windows-x64.zip', archive)
        target = root / 'jdk17'
        target.mkdir(exist_ok=True)
        with zipfile.ZipFile(archive) as z:
            for info in z.infolist():
                if info.is_dir(): continue
                name = info.filename.split('/', 1)[1]
                dest = target / name
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(z.read(info))
        print('JDK17 ready', flush=True)
