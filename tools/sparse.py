#!/usr/bin/env python3
"""
img2simg / simg2img — implementacion pura del formato "sparse" de Android.

Sparse = imagen con los bloques de ceros sin escribir. fastboot lo acepta
igual que una imagen cruda, pero ocupa mucho menos.

Formato (todo little-endian):

  sparse_header (28 bytes):
    u32 magic        0xED26FF3A
    u16 major        1
    u16 minor        0
    u16 file_hdr_sz  28
    u16 chunk_hdr_sz 12
    u32 blk_sz       4096
    u32 total_blks   bloques de la imagen original
    u32 total_chunks numero de chunks que siguen
    u32 checksum     suma de todos los bytes de los datos originales

  chunk_header (12 bytes):
    u16 chunk_type   0xCAC1 raw, 0xCAC2 fill, 0xCAC3 don't-care
    u16 reserved     0
    u32 chunk_sz     tamano en BLOQUES
    u32 total_sz     tamano total en bytes, incluida esta cabecera

Uso:
  python3 sparse.py pack   <entrada.img> <salida.simg>   # crudo -> sparse
  python3 sparse.py unpack <entrada.simg> <salida.img>   # sparse -> crudo
  python3 sparse.py info   <fichero>                     # ver cabecera
"""
import os
import struct
import sys

MAGIC = 0xED26FF3A
CHUNK_RAW = 0xCAC1
CHUNK_FILL = 0xCAC2
CHUNK_DONT_CARE = 0xCAC3

BLK = 4096
# Un chunk FILL cubre bloques consecutivos identicos. Limite de bloques por
# chunk para que el fichero no lleve un chunk gigante (los tools de Android
# usan como maximo esto).
MAX_CHUNK_BLKS = 1024 * 1024

HDR_FMT = "<IHHHHIIII"
CHK_FMT = "<HHII"


def info(path):
    with open(path, "rb") as f:
        raw = f.read(struct.calcsize(HDR_FMT))
        if len(raw) < struct.calcsize(HDR_FMT):
            print("  fichero demasiado corto")
            return None
        (magic, major, minor, fhsz, chsz, blk, tblks, tchunks, csum) = struct.unpack(HDR_FMT, raw)
    if magic != MAGIC:
        print(f"  no es sparse (magic=0x{magic:08X})")
        return None
    print(f"  magic        : 0x{magic:08X}  (OK)")
    print(f"  version      : {major}.{minor}")
    print(f"  file_hdr_sz  : {fhsz}")
    print(f"  chunk_hdr_sz : {chsz}")
    print(f"  blk_sz       : {blk}")
    print(f"  total_blks   : {tblks}  ({tblks*blk/1073741824:.2f} GB)")
    print(f"  total_chunks : {tchunks}")
    print(f"  checksum     : 0x{csum:08X}")
    return dict(blk=blk, tblks=tblks, tchunks=tchunks, fhsz=fhsz, chsz=chsz, csum=csum)


def pack(src, dst):
    size = os.path.getsize(src)
    tblks = (size + BLK - 1) // BLK
    print(f"  entrando : {src}  ({size} bytes, {tblks} bloques)")

    # 1a pasada: decidir chunks y calcular checksum
    chunks = []          # (tipo, n_bloques, payload_o_valor_relleno)
    csum = 0
    with open(src, "rb") as f:
        pos = 0
        while pos < tblks:
            data = f.read(BLK * MAX_CHUNK_BLKS)
            if not data:
                break
            n = (len(data) + BLK - 1) // BLK
            csum = (csum + sum(data)) & 0xFFFFFFFF
            # partir en runs de bloques identicos
            i = 0
            while i < n:
                blkdata = data[i * BLK:(i + 1) * BLK]
                if len(blkdata) < BLK:
                    blkdata = blkdata + b"\x00" * (BLK - len(blkdata))
                if blkdata == b"\x00" * BLK:
                    # run de ceros
                    j = i + 1
                    while j < n and data[j * BLK:(j + 1) * BLK].ljust(BLK, b"\x00") == b"\x00" * BLK:
                        j += 1
                    chunks.append(("dontcare", j - i))
                    i = j
                else:
                    # run de bloques con datos
                    j = i
                    buf = b""
                    while j < n:
                        b2 = data[j * BLK:(j + 1) * BLK]
                        if len(b2) < BLK:
                            b2 = b2 + b"\x00" * (BLK - len(b2))
                        if b2 == b"\x00" * BLK:
                            break
                        buf += b2
                        j += 1
                    chunks.append(("raw", j - i, buf))
                    i = j
            pos += n

    print(f"  chunks   : {len(chunks)}")

    # 2a pasada: escribir
    with open(dst, "wb") as f:
        f.write(struct.pack(HDR_FMT, MAGIC, 1, 0,
                            struct.calcsize(HDR_FMT), struct.calcsize(CHK_FMT),
                            BLK, tblks, len(chunks), csum))
        for c in chunks:
            if c[0] == "dontcare":
                f.write(struct.pack(CHK_FMT, CHUNK_DONT_CARE, 0, c[1], struct.calcsize(CHK_FMT)))
            else:
                payload = c[2]
                f.write(struct.pack(CHK_FMT, CHUNK_RAW, 0, c[1],
                                    struct.calcsize(CHK_FMT) + len(payload)))
                f.write(payload)
    print(f"  salida   : {dst}  ({os.path.getsize(dst)} bytes)")


def unpack(src, dst):
    h = info(src)
    if not h:
        return 1
    blk = h["blk"]
    remaining = h["tblks"]
    with open(src, "rb") as f, open(dst, "wb") as o:
        f.seek(h["fhsz"])
        nch = 0
        while nch < h["tchunks"] and remaining > 0:
            raw = f.read(h["chsz"])
            if len(raw) < h["chsz"]:
                break
            ctype, _res, csz, tsz = struct.unpack(CHK_FMT, raw)
            nch += 1
            if ctype == CHUNK_RAW:
                payload = f.read(tsz - h["chsz"])
                o.write(payload)
            elif ctype == CHUNK_FILL:
                val = f.read(4)
                o.write(val * csz)
            elif ctype == CHUNK_DONT_CARE:
                o.write(b"\x00" * (csz * blk))
            else:
                print(f"  chunk tipo desconocido 0x{ctype:04X}")
                return 1
            remaining -= csz
    print(f"  salida   : {dst}  ({os.path.getsize(dst)} bytes)")
    return 0


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    cmd = sys.argv[1]
    if cmd == "info":
        info(sys.argv[2])
    elif cmd == "pack":
        pack(sys.argv[2], sys.argv[3])
    elif cmd == "unpack":
        sys.exit(unpack(sys.argv[2], sys.argv[3]))
    else:
        print(__doc__)
        sys.exit(1)
