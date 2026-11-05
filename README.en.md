# TPC1013 / Allwinner A133 — Full restoration package

[🇪🇸 Versión en español](README.md)

**Verified** firmware images for the Allwinner A133 tablet (`ceres`,
`sun50iw10p1`) sold as **TPC1013** (also seen as LVILLE, and it shares hardware
with the PRITOM M10).

Use it to **restore** a bricked tablet or **clone** the system onto another
unit of the same model.

---

## ⚠️ Read this before flashing

**This erases the tablet completely.** And it only works on **identical**
hardware:

| You need | Value |
|---|---|
| SoC | Allwinner A133 (`ceres`, `sun50iw10p1`) |
| RAM | 2 GB |
| Storage | eMMC |
| Display | BOE9365 panel, 800×1280 |
| WiFi | 8800DC chip |
| Base build | Android 13 Go, `SY13` |

Check yours with:

```bash
adb shell getprop ro.yhk_flavor.id
# must contain: TPC1013_BOE9365_..._8800DC
adb shell getprop ro.product.device
# must say: TPC1013
```

If your tablet does not match **exactly**, do not flash it. It will boot with no
display or no WiFi, or simply not boot at all.

**This package is tested on one real TPC1013.** I cannot guarantee it works on
every unit sold under that name, because different variants with other panels
and other network chips circulate under the same reference.

---

## What is in here

| File | Bytes | What it is |
|---|---|---|
| `super.simg` | ~1.6 GB | **The whole system**: system, vendor, product, system_dlkm, vendor_dlkm. Lives in [Releases](../../releases), not in the repo (3.5 GB raw, stored *sparse* so it fits). |
| `images/boot_a.img` | 67108864 | GKI kernel 5.15.189. **This is the one that makes the tablet boot.** |
| `images/init_boot_a.img` | 8388608 | Stock init_boot. **This is where Magisk goes** if you want root. |
| `images/vendor_boot_a.img` | 33554432 | Vendor ramdisk + modules. |
| `images/dtbo_a.img` | 2097152 | Device tree overlay. |
| `images/vbmeta_a.img` | 131072 | **vbmeta with `flags=2`** (verity disabled). This is what avoids the signature problem. |
| `images/vbmeta_system_a.img` | 65536 | |
| `images/vbmeta_vendor_a.img` | 65536 | |
| `images/misc.img` | 16777216 | BCB. Clean, no pending recovery commands. |
| `images/*_b.img` | various | Same partitions for slot B, as a fallback. |
| `SHA256SUMS.txt` | — | Checksums for everything. |
| `scripts/flash.sh` | — | Interactive script, Spanish and English. |

### What it deliberately does **not** include

- **`bootloader`** — Verified: it is not the SPL. It is a **FAT16 partition
  holding the bootloader logos and fonts** (`BOOTLOGO.BMP`, `FONT24.SFT`…). The
  real SPL/U-Boot lives in the first 128 KB of the eMMC, outside the
  partitions, and cannot be dumped from Android.
- **`env`** — Holds the source unit's `slot_suffix`. Keep your own.
- **`frp`, `metadata`, `private`** — Identity and encryption keys of the source
  unit. Not published.
- **`userdata`** — Your data. Never shared.
- **`boot_b`** — A hand-compiled kernel from diagnostics, **not factory**, and
  this bootloader rejects it. Excluded.

---

## How to flash

### Option A — Interactive script (recommended)

Download the package, enter the folder, run:

```bash
bash scripts/flash.sh
```

The script asks for your language, shows the warnings, **verifies every SHA256
checksum before writing anything**, and lets you choose:

1. Full flash + wipe data
2. Full flash keeping data
3. Rescue: boot partitions only
4. Verify checksums only (writes nothing)
5. Exit

### Option B — By hand

```bash
fastboot flash super           super.simg
fastboot flash boot_a          images/boot_a.img
fastboot flash init_boot_a     images/init_boot_a.img
fastboot flash vendor_boot_a   images/vendor_boot_a.img
fastboot flash dtbo_a          images/dtbo_a.img
fastboot flash vbmeta_a        images/vbmeta_a.img
fastboot flash vbmeta_system_a images/vbmeta_system_a.img
fastboot flash vbmeta_vendor_a images/vbmeta_vendor_a.img
fastboot -w
fastboot reboot
```

`-w` wipes user data. Drop it if you want to keep it.

---

## The step nobody expects: on Windows you must use WSL

**On Windows, `fastboot` does not see this tablet.** The bootloader shows up as
`VID_1F3A:PID_1010` and Windows binds it to a driver fastboot cannot use (it
appears as *"USB Developer"* with status **Error** in Device Manager).

The reliable fix is to hand the USB device over to WSL:

```powershell
# PowerShell AS ADMINISTRATOR, once:
usbipd bind --busid <ID> --force
usbipd attach --wsl --busid <ID>
```

Find `<ID>` with `usbipd list` — the tablet is the line showing `1f3a:1010`.

Then, from WSL:

```bash
cd /mnt/d/path/to/repo
bash scripts/flash.sh
```

`usbipd attach --wsl` needs **no sudo** and no password: it loads the
`vhci_hcd` module itself. (The WSL kernel already ships
`CONFIG_USBIP_VHCI_HCD=m`.)

### Entering fastboot mode

```bash
adb reboot bootloader
```

Or power the tablet off and on again with the bootloader key combination. If it
is bricked and will not boot, only the key combination works.

---

## How to get root (Magisk)

This package ships **no** root: `init_boot_a.img` is the clean stock image.

The procedure that worked, summarised:

1. Install [Magisk](https://github.com/topjohnwu/Magisk) (v31.1 tested).
2. Extract the **`lib/armeabi-v7a/`** binaries from the APK (this tablet has a
   32-bit userspace even though the kernel is arm64) and rename them:
   `libmagiskboot.so`→`magiskboot`, `libmagiskinit.so`→`magiskinit`,
   `libinit-ld.so`→`init-ld`, `libmagisk.so`→`magisk`.
3. Push them to the tablet along with `boot_patch.sh` and `util_functions.sh`
   (both in the APK's `assets/`) and run:

   ```bash
   KEEPVERITY=true KEEPFORCEENCRYPT=true sh boot_patch.sh init_boot_a.img
   ```

4. Flash the resulting `new-boot.img` to `init_boot_a`.
5. Boot, open Magisk → **Superuser** → `+` → tick **Shell** → confirm.

**Details that matter:**

- You patch **`init_boot`, not `boot`**. This device is GKI with a separate
  `init_boot`.
- Patch **on the device**, not on the PC: the script calls binaries of the
  correct architecture.
- If `su` returns `Permission denied` with no dialog, there is no configured
  authentication method (the tablet has no PIN). Fix it by granting the
  permission to **Shell** from the app, as in step 5.
- **Zygisk needs a reboot** to inject into `zygote`. If you enable it while the
  system is already running, it is saved but not applied until you reboot.

---

## How this package was produced

Everything was dumped over ADB **with root**, reading the block devices
directly:

```bash
su -c 'dd if=/dev/block/by-name/super of=/data/local/tmp/super.img bs=4M'
```

**Verifications performed:**

| Check | Result |
|---|---|
| SHA256 source (tablet) vs destination (PC) | **identical** |
| `super.img` dumped a second time by an independent tool (Tenkai Studio) | **13/13 files identical** |
| `LP_METADATA_GEOMETRY_MAGIC` (`gDla`) signature at offset 4096 | present |
| Logical partitions inside `super` (`system_a`, `vendor_a`, `product_a`…) | all located |
| `super.simg` *sparse* reverted and compared against the raw image | **identical** |
| Scan of `super` for personal data (serial, MAC, email) | **0 hits** |

### About the *sparse* format

The raw `super` is 3.5 GB, but only ~1.7 GB holds data; the rest is zeros. The
Android *sparse* format skips empty blocks, and `fastboot` accepts it exactly
like a raw image.

The included [`tools/sparse.py`](tools/sparse.py) implements the format (in case
you want to convert back to raw or generate it yourself):

```bash
python3 tools/sparse.py unpack super.simg super.img   # sparse -> raw
python3 tools/sparse.py pack   super.img super.simg   # raw -> sparse
python3 tools/sparse.py info   super.simg             # show header
```

---

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `fastboot devices` empty on Windows | You need WSL + `usbipd attach --wsl`. See above. |
| Stuck on a static logo | Wrong `boot`. Re-flash `images/boot_a.img` and `images/vbmeta_a.img`. |
| Boots but no display / no WiFi | Your panel or WiFi chip is not BOE9365 / 8800DC. Different hardware. |
| `Writing 'super' … FAILED` | Partition size mismatch. Make sure it is a TPC1013. |
| `su` does not work after rooting | Grant the permission to **Shell** from the Magisk app. |
| Zygisk shows as disabled | Reboot the tablet. |

### Minimum rescue

If something goes wrong and you only want it to **boot**:

```bash
fastboot flash boot_a   images/boot_a.img
fastboot flash vbmeta_a images/vbmeta_a.img
fastboot reboot
```

---

## Serial numbers and personal data

Every tablet keeps **its own identity**. This package does not touch it:

- The serial (`MB1001…`) and the WiFi MAC are **not** in `super` — verified by
  scanning all 3.5 GB, 0 hits.
- They live outside the partitions being flashed (the MAC in the `keybox`, at
  the start of the eMMC), so **they are not overwritten**.

---

## Licence and liability

No warranty of any kind. Flashing can leave the device unusable. You do this at
your own risk, and only if you have a way to recover it.

The binaries are dumps from a legally acquired unit. Android is a trademark of
Google; Allwinner and its tools belong to their respective owners.
