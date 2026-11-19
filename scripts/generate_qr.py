#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Čistý Python generátor QR platebních kódů (SPAYD standard ČR).
Nevyžaduje žádné kompilované binárky ani PIL, funguje 100% spolehlivě
na hostiteli i v jakémkoliv Flatpak/sandbox kontejneru.
"""
import os
import sys
import zlib
import struct
import argparse
import unicodedata
import re

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
LIB_DIR = os.path.join(SCRIPT_DIR, "lib")
if os.path.exists(LIB_DIR) and LIB_DIR not in sys.path:
    sys.path.insert(0, LIB_DIR)

import qrcode

def clean_ascii(text):
    if not text:
        return ""
    text_norm = unicodedata.normalize('NFD', str(text))
    text_ascii = ''.join(c for c in text_norm if unicodedata.category(c) != 'Mn')
    return re.sub(r'[*]', '', text_ascii).strip()

def build_spayd(iban, amount, vs=None, msg=None, due_date=None, currency="CZK"):
    clean_iban = re.sub(r'[^A-Z0-9]', '', str(iban).upper())
    parts = ["SPD*1.0", f"ACC:{clean_iban}"]
    
    if amount is not None:
        try:
            val = float(str(amount).replace(' ', '').replace(',', '.'))
            parts.append(f"AM:{val:.2f}")
        except ValueError:
            pass
            
    parts.append(f"CC:{currency}")
    
    if vs:
        clean_vs = re.sub(r'[^0-9]', '', str(vs))
        if clean_vs:
            parts.append(f"X-VS:{clean_vs[:10]}")
            
    if msg:
        c_msg = clean_ascii(msg)[:60]
        if c_msg:
            parts.append(f"MSG:{c_msg}")
            
    if due_date:
        c_dt = re.sub(r'[^0-9]', '', str(due_date))
        if len(c_dt) == 8:
            parts.append(f"DT:{c_dt}")
            
    return "*".join(parts)

def write_png_qr(matrix, filename, scale=8, border=3):
    """Zapíše matici QR kódu přímo do validního PNG souboru bez PIL knihovny."""
    n = len(matrix)
    width = (n + 2 * border) * scale
    height = width
    
    raw_data = bytearray()
    white_row = bytes([255] * width)
    
    # Horní okraj
    for _ in range(border * scale):
        raw_data.append(0)
        raw_data.extend(white_row)
        
    for r in range(n):
        row_bytes = bytearray()
        row_bytes.extend([255] * (border * scale))
        for c in range(n):
            val = 0 if matrix[r][c] else 255
            row_bytes.extend([val] * scale)
        row_bytes.extend([255] * (border * scale))
        
        for _ in range(scale):
            raw_data.append(0)
            raw_data.extend(row_bytes)
            
    # Dolní okraj
    for _ in range(border * scale):
        raw_data.append(0)
        raw_data.extend(white_row)
        
    def chunk(tag, data):
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)
        
    png = bytearray(b'\x89PNG\r\n\x1a\n')
    ihdr = struct.pack('>IIBBBBB', width, height, 8, 0, 0, 0, 0)
    png.extend(chunk(b'IHDR', ihdr))
    png.extend(chunk(b'IDAT', zlib.compress(bytes(raw_data), 9)))
    png.extend(chunk(b'IEND', b''))
    
    out_dir = os.path.dirname(os.path.abspath(filename))
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
        
    with open(filename, 'wb') as f:
        f.write(png)

def generate_qr(spayd_str, output_png, scale=8):
    qr = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_M, box_size=1, border=0)
    qr.add_data(spayd_str)
    qr.make(fit=True)
    write_png_qr(qr.modules, output_png, scale=scale, border=3)
    return output_png

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generátor QR platebních kódů (SPAYD)")
    parser.add_argument("--iban", required=True, help="IBAN účtu příjemce")
    parser.add_argument("--amount", type=float, required=True, help="Částka k úhradě")
    parser.add_argument("--vs", help="Variabilní symbol")
    parser.add_argument("--msg", help="Zpráva pro příjemce")
    parser.add_argument("--due-date", help="Datum splatnosti (YYYYMMDD)")
    parser.add_argument("--output", required=True, help="Cesta k výstupnímu souboru PNG")
    parser.add_argument("--scale", type=int, default=8, help="Měřítko pixelů na modul")
    
    args = parser.parse_args()
    spayd = build_spayd(args.iban, args.amount, args.vs, args.msg, args.due_date)
    print(f"SPAYD: {spayd}")
    generate_qr(spayd, args.output, scale=args.scale)
    print(f"QR PNG úspěšně vytvořen: {args.output}")
