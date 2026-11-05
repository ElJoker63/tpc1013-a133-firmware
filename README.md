# TPC1013 / Allwinner A133 — Paquete de restauración completo

[🇬🇧 English version](README.en.md)

Imágenes de firmware **verificadas** para el tablet Allwinner A133 (`ceres`,
`sun50iw10p1`) comercializado como **TPC1013** (también aparece como LVILLE,
y comparte hardware con el PRITOM M10).

Sirve para **restaurar** un tablet brickeado o **clonar** el sistema en otra
unidad del mismo modelo.

---

## ⚠️ Léelo antes de flashear

**Esto borra el tablet por completo.** Y solo vale para hardware **idéntico**:

| Necesitas | Valor |
|---|---|
| SoC | Allwinner A133 (`ceres`, `sun50iw10p1`) |
| RAM | 2 GB |
| Almacenamiento | eMMC |
| Pantalla | panel BOE9365, 800×1280 |
| WiFi | chip 8800DC |
| Build base | Android 13 Go, `SY13` |

Para comprobarlo en tu tablet:

```bash
adb shell getprop ro.yhk_flavor.id
# debe contener: TPC1013_BOE9365_..._8800DC
adb shell getprop ro.product.device
# debe decir: TPC1013
```

Si tu tablet no coincide **exactamente**, no lo flashees. Arrancará sin pantalla
o sin WiFi, o directamente no arrancará.

**Este paquete está probado en un TPC1013 real.** No puedo garantizar que
funcione en todas las unidades que se venden con ese nombre, porque bajo la
misma referencia circulan variantes con otro panel y otro chip de red.

---

## Qué hay aquí

| Fichero | Bytes | Qué es |
|---|---|---|
| `super.simg` | ~1,6 GB | **El sistema completo**: system, vendor, product, system_dlkm, vendor_dlkm. Va en la sección [Releases](../../releases), no en el repo (3,5 GB en crudo, formato *sparse* para que quepa). |
| `images/boot_a.img` | 67108864 | Kernel GKI 5.15.189. **Este es el que hace arrancar el tablet.** |
| `images/init_boot_a.img` | 8388608 | init_boot stock. **Aquí es donde se instala Magisk** si quieres root. |
| `images/vendor_boot_a.img` | 33554432 | Ramdisk del vendor + módulos. |
| `images/dtbo_a.img` | 2097152 | Device tree overlay. |
| `images/vbmeta_a.img` | 131072 | **vbmeta con `flags=2`** (verificación desactivada). Es lo que evita el problema de firma. |
| `images/vbmeta_system_a.img` | 65536 | |
| `images/vbmeta_vendor_a.img` | 65536 | |
| `images/misc.img` | 16777216 | BCB. Limpio, sin comandos de recovery pendientes. |
| `images/*_b.img` | varios | Las mismas particiones del slot B, de reserva. |
| `SHA256SUMS.txt` | — | Sumas de control de todo. |
| `scripts/flash.sh` | — | Script interactivo, español e inglés. |

### Lo que **no** incluye (a propósito)

- **`bootloader`** — Comprobado: no es el SPL. Es una partición **FAT16 con los
  logos y fuentes del cargador** (`BOOTLOGO.BMP`, `FONT24.SFT`…). El SPL/U-Boot
  real vive en los primeros 128 KB de la eMMC, fuera de las particiones, y no
  se puede volcar desde Android.
- **`env`** — Contiene la variable `slot_suffix` de la unidad de origen.
  Debes conservar la tuya.
- **`frp`, `metadata`, `private`** — Identidad y claves de cifrado de la unidad
  de origen. No se publican.
- **`userdata`** — Tus datos. Nunca se comparte.
- **`boot_b`** — Kernel compilado a mano durante el diagnóstico, **no es de
  fábrica** y este bootloader lo rechaza. Excluido.

---

## Cómo flashear

### Opción A — Script interactivo (recomendado)

Descarga el paquete, entra en la carpeta y ejecuta:

```bash
bash scripts/flash.sh
```

El script te pregunta el idioma, te muestra los avisos, **verifica todas las
sumas SHA256 antes de escribir nada**, y te deja elegir:

1. Flasheo completo + borrar datos
2. Flasheo completo conservando datos
3. Rescate: solo particiones de arranque
4. Solo verificar sumas (no escribe)
5. Salir

### Opción B — A mano

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

`-w` borra los datos de usuario. Quítalo si quieres conservarlos.

---

## El paso que casi nadie espera: en Windows hay que usar WSL

**En Windows, `fastboot` no ve este tablet.** El bootloader se presenta como
`VID_1F3A:PID_1010` y Windows le asigna un driver que fastboot no reconoce
(aparece como *"USB Developer"* con estado **Error** en el Administrador de
dispositivos).

La solución fiable es pasar el USB a WSL:

```powershell
# PowerShell COMO ADMINISTRADOR, una sola vez:
usbipd bind --busid <ID> --force
usbipd attach --wsl --busid <ID>
```

Localiza `<ID>` con `usbipd list` — la línea del tablet es la que pone
`1f3a:1010`.

Luego, desde WSL:

```bash
cd /mnt/d/ruta/al/repo
bash scripts/flash.sh
```

`usbipd attach --wsl` **no necesita sudo** ni contraseña: carga él mismo el
módulo `vhci_hcd`. (El kernel de WSL ya trae `CONFIG_USBIP_VHCI_HCD=m`.)

### Entrar en modo fastboot

```bash
adb reboot bootloader
```

O apagando el tablet y encendiéndolo con la combinación de teclas del
bootloader. Si estás brickeado y no arranca, solo la combinación de teclas.

---

## Cómo conseguir root (Magisk)

Este paquete **no** trae root: `init_boot_a.img` es la imagen stock limpia.

El procedimiento que funcionó, resumido:

1. Instala [Magisk](https://github.com/topjohnwu/Magisk) (v31.1 probado).
2. Extrae del APK los binarios de **`lib/armeabi-v7a/`** (este tablet es
   userspace de 32 bits aunque el kernel sea arm64) y renómbralos:
   `libmagiskboot.so`→`magiskboot`, `libmagiskinit.so`→`magiskinit`,
   `libinit-ld.so`→`init-ld`, `libmagisk.so`→`magisk`.
3. Súbelos al tablet junto a `boot_patch.sh` y `util_functions.sh` (están en
   `assets/` del APK) y ejecuta:

   ```bash
   KEEPVERITY=true KEEPFORCEENCRYPT=true sh boot_patch.sh init_boot_a.img
   ```

4. Flashea el `new-boot.img` resultante en `init_boot_a`.
5. Arranca, abre Magisk → **Superusuario** → `+` → marca **Shell** → confirma.

**Detalles que importan:**

- Se parchea **`init_boot`, no `boot`**. Este dispositivo es GKI con
  `init_boot` separado.
- Hay que parchear **en el dispositivo**, no en el PC: el script llama a
  binarios de la arquitectura correcta.
- Si `su` da `Permission denied` sin mostrar diálogo, es que no hay método de
  autenticación configurado (el tablet no tiene PIN). Se arregla concediendo el
  permiso a **Shell** desde la app, como en el paso 5.
- **Zygisk necesita un reinicio** para inyectarse en `zygote`. Si lo activas
  con el sistema ya arrancado, se guarda pero no se aplica hasta que reinicies.

---

## Cómo se obtuvo este paquete

Todo se volcó por ADB **con root**, leyendo directamente los dispositivos de
bloque:

```bash
su -c 'dd if=/dev/block/by-name/super of=/data/local/tmp/super.img bs=4M'
```

**Verificaciones realizadas:**

| Comprobación | Resultado |
|---|---|
| Hash SHA256 origen (tablet) vs destino (PC) | **idéntico** |
| `super.img` volcado por segunda vía independiente (Tenkai Studio) | **13/13 ficheros idénticos** |
| Firma `LP_METADATA_GEOMETRY_MAGIC` (`gDla`) en offset 4096 | presente |
| Particiones lógicas dentro del `super` (`system_a`, `vendor_a`, `product_a`…) | todas localizadas |
| `super.simg` *sparse* revertido con `simg2img` y comparado | **idéntico al crudo** |
| Búsqueda de datos personales en `super` (serial, MAC, email) | **0 coincidencias** |

### Sobre el formato *sparse*

El `super` en crudo son 3,5 GB, pero solo ~1,7 GB tienen datos; el resto son
ceros. El formato *sparse* de Android omite los bloques vacíos, y `fastboot` lo
acepta igual que una imagen cruda.

El script [`tools/sparse.py`](tools/sparse.py) incluido implementa el formato
(por si quieres volver a crudo o generarlo tú):

```bash
python3 tools/sparse.py unpack super.simg super.img   # sparse -> crudo
python3 tools/sparse.py pack   super.img super.simg   # crudo -> sparse
python3 tools/sparse.py info   super.simg             # ver cabecera
```

---

## Solución de problemas

| Síntoma | Causa y solución |
|---|---|
| `fastboot devices` vacío en Windows | Necesitas WSL + `usbipd attach --wsl`. Ver arriba. |
| Se queda en el logo fijo | `boot` incorrecto. Vuelve a flashear `images/boot_a.img` y `images/vbmeta_a.img`. |
| Arranca pero sin pantalla / sin WiFi | Tu panel o chip WiFi no son BOE9365 / 8800DC. Hardware distinto. |
| `Writing 'super' … FAILED` | Partición de tamaño distinto. Comprueba que sea un TPC1013. |
| `su` no funciona tras el root | Concede el permiso a **Shell** desde la app Magisk. |
| Zygisk sale desactivado | Reinicia el tablet. |

### Rescate mínimo

Si algo sale mal y solo quieres que **arranque**:

```bash
fastboot flash boot_a   images/boot_a.img
fastboot flash vbmeta_a images/vbmeta_a.img
fastboot reboot
```

---

## Números de serie y datos personales

Cada tablet conserva **su propia identidad**. Este paquete no la toca:

- El serial (`MB1001…`) y la MAC WiFi **no están** en `super` — verificado con
  búsqueda sobre los 3,5 GB, 0 coincidencias.
- Viven fuera de las particiones que se flashean (la MAC en el `keybox`, al
  principio de la eMMC), así que **no se sobrescriben**.

---

## Licencia y responsabilidad

Sin garantía de ningún tipo. Flashear puede dejar el dispositivo inutilizable.
Vas bajo tu propia responsabilidad, y solo si tienes forma de recuperarlo.

Los binarios son volcados de una unidad adquirida legalmente. Android es marca
de Google; Allwinner y sus herramientas pertenecen a sus respectivos dueños.
