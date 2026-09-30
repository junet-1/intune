#!/usr/bin/env python3
"""Baut eine .intunewin-Datei unter Linux.

IntuneWinAppUtil.exe laeuft nur unter Windows (und scheitert unter Wine an
System.IO.Packaging). Dieses Skript erzeugt dasselbe Format:

    <paket>.intunewin                        (ZIP)
      IntuneWinPackage/Metadata/Detection.xml
      IntuneWinPackage/Contents/IntunePackage.intunewin

Der Inhalt ist ein unkomprimiertes ZIP des Quellordners, verschluesselt mit
AES-256-CBC (PKCS7) und mit HMAC-SHA256 signiert. Aufbau der verschluesselten
Datei: 32 Byte HMAC, 16 Byte IV, danach der Chiffretext. Der HMAC laeuft ueber
IV und Chiffretext.

Nach dem Bau prueft das Skript sich selbst: HMAC, IV, FileDigest, Groesse,
Gueltigkeit des inneren ZIP und Bit-Gleichheit jeder Quelldatei.

Aufruf:
    ./Build-IntuneWin.py -c <Quellordner> -s <Setupdatei> -o <Ausgabeordner>
"""

import argparse
import base64
import hashlib
import hmac
import os
import secrets
import sys
import tempfile
import zipfile
from pathlib import Path

from cryptography.hazmat.primitives import padding
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

TOOL_VERSION = "1.8.7.0"
INNER_NAME = "IntunePackage.intunewin"


def collect_files(source: Path) -> list[tuple[Path, str]]:
    """Alle Dateien unter source mit ihrem Pfad relativ zu source."""
    entries = []
    for path in sorted(source.rglob("*")):
        if path.is_file():
            entries.append((path, path.relative_to(source).as_posix()))
    if not entries:
        sys.exit(f"FEHLER: Quellordner ist leer: {source}")
    return entries


def build_inner_zip(entries: list[tuple[Path, str]], target: Path) -> None:
    """Unkomprimiertes ZIP des Quellordners, ohne Basisverzeichnis."""
    with zipfile.ZipFile(target, "w", zipfile.ZIP_STORED) as zf:
        for path, arcname in entries:
            zf.write(path, arcname)


def encrypt(plain: Path, target: Path) -> dict:
    key = secrets.token_bytes(32)
    mac_key = secrets.token_bytes(32)
    iv = secrets.token_bytes(16)

    data = plain.read_bytes()
    padder = padding.PKCS7(algorithms.AES.block_size).padder()
    padded = padder.update(data) + padder.finalize()

    encryptor = Cipher(algorithms.AES(key), modes.CBC(iv)).encryptor()
    ciphertext = encryptor.update(padded) + encryptor.finalize()

    mac = hmac.new(mac_key, iv + ciphertext, hashlib.sha256).digest()
    target.write_bytes(mac + iv + ciphertext)

    return {
        "EncryptionKey": base64.b64encode(key).decode(),
        "MacKey": base64.b64encode(mac_key).decode(),
        "InitializationVector": base64.b64encode(iv).decode(),
        "Mac": base64.b64encode(mac).decode(),
        "ProfileIdentifier": "ProfileVersion1",
        "FileDigest": base64.b64encode(hashlib.sha256(data).digest()).decode(),
        "FileDigestAlgorithm": "SHA256",
    }


def build_detection_xml(name: str, setup_file: str, size: int, info: dict) -> str:
    order = [
        "EncryptionKey",
        "MacKey",
        "InitializationVector",
        "Mac",
        "ProfileIdentifier",
        "FileDigest",
        "FileDigestAlgorithm",
    ]
    lines = [f"    <{k}>{info[k]}</{k}>" for k in order]
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<ApplicationInfo xmlns:xsd="http://www.w3.org/2001/XMLSchema"'
        ' xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"'
        f' ToolVersion="{TOOL_VERSION}">\n'
        f"  <Name>{name}</Name>\n"
        f"  <UnencryptedContentSize>{size}</UnencryptedContentSize>\n"
        f"  <FileName>{INNER_NAME}</FileName>\n"
        f"  <SetupFile>{setup_file}</SetupFile>\n"
        "  <EncryptionInfo>\n" + "\n".join(lines) + "\n"
        "  </EncryptionInfo>\n"
        "</ApplicationInfo>"
    )


def verify(package: Path, entries: list[tuple[Path, str]], info: dict, size: int) -> None:
    """Paket wieder auseinandernehmen und gegen die Quelle pruefen."""
    checks = []

    with zipfile.ZipFile(package) as outer:
        names = outer.namelist()
        checks.append(("Aufbau des aeusseren ZIP", sorted(names) == sorted(
            ["IntuneWinPackage/Metadata/Detection.xml",
             f"IntuneWinPackage/Contents/{INNER_NAME}"])))
        blob = outer.read(f"IntuneWinPackage/Contents/{INNER_NAME}")
        xml = outer.read("IntuneWinPackage/Metadata/Detection.xml").decode("utf-8")

    mac, iv, ciphertext = blob[:32], blob[32:48], blob[48:]
    mac_key = base64.b64decode(info["MacKey"])
    key = base64.b64decode(info["EncryptionKey"])

    checks.append(("HMAC ueber IV und Chiffretext", hmac.compare_digest(
        mac, hmac.new(mac_key, iv + ciphertext, hashlib.sha256).digest())))
    checks.append(("IV stimmt mit Detection.xml ueberein",
                   iv == base64.b64decode(info["InitializationVector"])))
    checks.append(("Mac stimmt mit Detection.xml ueberein",
                   mac == base64.b64decode(info["Mac"])))

    decryptor = Cipher(algorithms.AES(key), modes.CBC(iv)).decryptor()
    padded = decryptor.update(ciphertext) + decryptor.finalize()
    unpadder = padding.PKCS7(algorithms.AES.block_size).unpadder()
    plain = unpadder.update(padded) + unpadder.finalize()

    checks.append(("FileDigest (SHA256 des Klartext-ZIP)",
                   base64.b64encode(hashlib.sha256(plain).digest()).decode()
                   == info["FileDigest"]))
    checks.append(("UnencryptedContentSize", len(plain) == size
                   and f"<UnencryptedContentSize>{size}<" in xml))

    with tempfile.TemporaryDirectory() as tmp:
        inner_path = Path(tmp) / "inner.zip"
        inner_path.write_bytes(plain)
        with zipfile.ZipFile(inner_path) as inner:
            checks.append(("Inneres ZIP lesbar", inner.testzip() is None))
            checks.append(("Dateiliste vollstaendig",
                           sorted(inner.namelist()) == sorted(a for _, a in entries)))
            identical = all(
                inner.read(arc) == path.read_bytes() for path, arc in entries)
            checks.append(("Quelldateien bit-identisch", identical))

    width = max(len(label) for label, _ in checks)
    for label, ok in checks:
        print(f"  {label.ljust(width)}  {'ok' if ok else 'FEHLER'}")
    if not all(ok for _, ok in checks):
        sys.exit("FEHLER: Pruefung fehlgeschlagen, Paket nicht verwenden.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Baut eine .intunewin-Datei.")
    parser.add_argument("-c", "--content", required=True, help="Quellordner")
    parser.add_argument("-s", "--setup", required=True, help="Setupdatei im Quellordner")
    parser.add_argument("-o", "--output", required=True, help="Ausgabeordner")
    args = parser.parse_args()

    source = Path(args.content).resolve()
    setup = Path(args.setup)
    setup_name = setup.name
    output_dir = Path(args.output).resolve()

    if not source.is_dir():
        sys.exit(f"FEHLER: Quellordner nicht gefunden: {source}")
    if not (source / setup_name).is_file():
        sys.exit(f"FEHLER: Setupdatei nicht im Quellordner: {setup_name}")
    output_dir.mkdir(parents=True, exist_ok=True)

    entries = collect_files(source)
    package = output_dir / f"{Path(setup_name).stem}.intunewin"

    with tempfile.TemporaryDirectory() as tmp:
        plain_zip = Path(tmp) / "plain.zip"
        encrypted = Path(tmp) / "encrypted.bin"

        build_inner_zip(entries, plain_zip)
        size = plain_zip.stat().st_size
        info = encrypt(plain_zip, encrypted)
        xml = build_detection_xml(Path(setup_name).stem, setup_name, size, info)

        with zipfile.ZipFile(package, "w", zipfile.ZIP_DEFLATED) as outer:
            outer.writestr("IntuneWinPackage/Metadata/Detection.xml", xml)
            outer.write(encrypted, f"IntuneWinPackage/Contents/{INNER_NAME}",
                        compress_type=zipfile.ZIP_STORED)

    print(f"Paket: {package}")
    print(f"Groesse: {package.stat().st_size} Bytes")
    print(f"SHA256: {hashlib.sha256(package.read_bytes()).hexdigest()}")
    print("Pruefung:")
    verify(package, entries, info, size)


if __name__ == "__main__":
    main()
