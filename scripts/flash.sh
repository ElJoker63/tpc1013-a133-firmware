#!/usr/bin/env bash
#
#  TPC1013 / Allwinner A133 — Interactive flasher
#  TPC1013 / Allwinner A133 — Flasheador interactivo
#
#  ES: Flashea el paquete completo en un tablet Allwinner A133 identico.
#  EN: Flashes the full package onto an identical Allwinner A133 tablet.
#
#  Uso / Usage:  bash flash.sh [es|en]
#
set -u

# ----------------------------------------------------------------------------
# i18n
# ----------------------------------------------------------------------------
LANG_SEL="${1:-}"

msg() {  # msg <clave>   -> imprime segun idioma
    local k="$1"
    if [ "$LANG_SEL" = "en" ]; then
        case "$k" in
            title)       echo "  TPC1013 (Allwinner A133) — Interactive Flasher" ;;
            warn)        echo "WARNING" ;;
            warnbody)    echo "  This ERASES the tablet completely (including /data).
  It is only for IDENTICAL hardware: Allwinner A133 (ceres), eMMC,
  display BOE9365, WiFi 8800DC.
  If your tablet is not the same model, DO NOT continue." ;;
            accept)      echo -n "  Type YES (uppercase) to accept and continue: " ;;
            noaccept)    echo "  Cancelled. Nothing was written." ;;
            checkdev)    echo "Checking device…" ;;
            nofastboot)  echo "  ERROR: no device in fastboot mode." ;;
            fbhint1)     echo "  Put the tablet in fastboot:  adb reboot bootloader" ;;
            fbhint2)     echo "  (or power off, then power on with the bootloader key combo)" ;;
            fbhint3)     echo "  On Windows, fastboot does NOT see this tablet: use WSL." ;;
            fbhint4)     echo "      usbipd bind   --busid <ID> --force   (once, as admin)" ;;
            fbhint5)     echo "      usbipd attach --wsl --busid <ID>" ;;
            found)       echo "  Device found:" ;;
            verify)      echo "Verifying image checksums…" ;;
            vok)         echo "  All checksums OK" ;;
            vbad)        echo "  MISMATCH in: %s" ;;
            badfile)     echo "  ERROR: missing file: %s" ;;
            plan)        echo "Will write, IN THIS ORDER:" ;;
            confirm)     echo -n "  Write to the tablet now? (YES): " ;;
            flashing)    echo "Flashing" ;;
            wiping)      echo "Wiping user data (fastboot -w)…" ;;
            done)        echo "DONE. The tablet will reboot." ;;
            reboot)      echo "Rebooting…" ;;
            noreboot)    echo "  Skipping reboot." ;;
            choose)      echo "Choose an option:" ;;
            o1)          echo "  1) Full flash (system + boot + vbmeta) + wipe data" ;;
            o2)          echo "  2) Full flash WITHOUT wiping data" ;;
            o3)          echo "  3) Recovery: boot partitions only (no super)" ;;
            o4)          echo "  4) Verify checksums only (write nothing)" ;;
            o5)          echo "  5) Exit" ;;
            opt)         echo -n "  Option [1-5]: " ;;
            onlyroot)    echo "  NOTE: to get root, flash init_boot_a-magisk.img separately." ;;
            *)           echo "$k" ;;
        esac
    else
        case "$k" in
            title)       echo "  TPC1013 (Allwinner A133) — Flasheador interactivo" ;;
            warn)        echo "AVISO" ;;
            warnbody)    echo "  Esto BORRA el tablet por completo (incluido /data).
  Solo vale para hardware IDENTICO: Allwinner A133 (ceres), eMMC,
  pantalla BOE9365, WiFi 8800DC.
  Si tu tablet no es el mismo modelo, NO continues." ;;
            accept)      echo -n "  Escribe SI (mayusculas) para aceptar y seguir: " ;;
            noaccept)    echo "  Cancelado. No se escribio nada." ;;
            checkdev)    echo "Comprobando dispositivo…" ;;
            nofastboot)  echo "  ERROR: no hay dispositivo en modo fastboot." ;;
            fbhint1)     echo "  Pon el tablet en fastboot:  adb reboot bootloader" ;;
            fbhint2)     echo "  (o apagalo y enciendelo con la combinacion de teclas)" ;;
            fbhint3)     echo "  En Windows, fastboot NO ve este tablet: usa WSL." ;;
            fbhint4)     echo "      usbipd bind   --busid <ID> --force   (una vez, como admin)" ;;
            fbhint5)     echo "      usbipd attach --wsl --busid <ID>" ;;
            found)       echo "  Dispositivo encontrado:" ;;
            verify)      echo "Verificando sumas de control…" ;;
            vok)         echo "  Todas las sumas correctas" ;;
            vbad)        echo "  NO COINCIDE en: %s" ;;
            badfile)     echo "  ERROR: falta el fichero: %s" ;;
            plan)        echo "Se escribira, EN ESTE ORDEN:" ;;
            confirm)     echo -n "  ¿Escribir en el tablet ahora? (SI): " ;;
            flashing)    echo "Flasheando" ;;
            wiping)      echo "Borrando datos de usuario (fastboot -w)…" ;;
            done)        echo "LISTO. El tablet va a reiniciar." ;;
            reboot)      echo "Reiniciando…" ;;
            noreboot)    echo "  Omitiendo reinicio." ;;
            choose)      echo "Elige una opcion:" ;;
            o1)          echo "  1) Flasheo completo (sistema + boot + vbmeta) + borrar datos" ;;
            o2)          echo "  2) Flasheo completo SIN borrar datos" ;;
            o3)          echo "  3) Rescate: solo particiones de arranque (sin super)" ;;
            o4)          echo "  4) Solo verificar sumas (no escribe nada)" ;;
            o5)          echo "  5) Salir" ;;
            opt)         echo -n "  Opcion [1-5]: " ;;
            onlyroot)    echo "  NOTA: para obtener root, flashea init_boot_a-magisk.img aparte." ;;
            *)           echo "$k" ;;
        esac
    fi
}

# ----------------------------------------------------------------------------
# Seleccion de idioma si no viene por argumento
# ----------------------------------------------------------------------------
if [ "$LANG_SEL" != "es" ] && [ "$LANG_SEL" != "en" ]; then
    echo
    echo "  Select language / Selecciona idioma:"
    echo "    1) Español"
    echo "    2) English"
    echo -n "  [1/2]: "
    read -r l
    case "$l" in
        2|en|EN|english) LANG_SEL=en ;;
        *)               LANG_SEL=es ;;
    esac
fi

DIR="$(cd "$(dirname "$0")/.." && pwd)"
IMG="$DIR/images"
FB="${FB:-fastboot}"

clear 2>/dev/null || true
echo
echo "============================================================"
msg title
echo "============================================================"
echo
echo "  $(msg warn)"
echo
msg warnbody
echo
msg accept
read -r ans
if [ "$LANG_SEL" = "en" ]; then
    [ "$ans" = "YES" ] || { echo; msg noaccept; exit 1; }
else
    [ "$ans" = "SI" ] || { echo; msg noaccept; exit 1; }
fi
echo

# ----------------------------------------------------------------------------
# Comprobar dispositivo
# ----------------------------------------------------------------------------
msg checkdev
if ! command -v "$FB" >/dev/null 2>&1; then
    echo "  ERROR: '$FB' not found / no encontrado"
    exit 1
fi
DEVLINE="$("$FB" devices 2>/dev/null | grep -v '^$' | head -1)"
if [ -z "$DEVLINE" ]; then
    echo
    msg nofastboot
    echo
    msg fbhint1
    msg fbhint2
    echo
    msg fbhint3
    msg fbhint4
    msg fbhint5
    echo
    exit 1
fi
msg found
echo "    $DEVLINE"
echo

# ----------------------------------------------------------------------------
# Verificacion de sumas
# ----------------------------------------------------------------------------
msg verify
SUMS="$DIR/SHA256SUMS.txt"
FAILED=""
if [ -f "$SUMS" ]; then
    while read -r h f; do
        [ -z "$h" ] && continue
        p="$DIR/$f"
        if [ ! -f "$p" ]; then printf "  $(msg badfile)\n" "$f"; FAILED="$FAILED $f"; continue; fi
        a="$(sha256sum "$p" | cut -d' ' -f1)"
        if [ "$a" != "$h" ]; then printf "  $(msg vbad)\n" "$f"; FAILED="$FAILED $f"; fi
    done < "$SUMS"
fi
# super va aparte (release), comprobar si esta descargado
SUPER=""
for c in "$IMG/super.simg" "$IMG/super.img" "$DIR/super.simg" "$DIR/super.img"; do
    [ -f "$c" ] && SUPER="$c" && break
done
if [ -n "$FAILED" ]; then
    echo
    echo "  ABORT: checksum mismatch / suma incorrecta"
    exit 1
fi
msg vok
echo

# ----------------------------------------------------------------------------
# Menu
# ----------------------------------------------------------------------------
msg choose
echo
msg o1
msg o2
msg o3
msg o4
msg o5
echo
msg opt
read -r OPT

case "$OPT" in
    4)
        echo
        if [ -n "$SUPER" ]; then echo "  super: $SUPER"; else
            echo "  (super image not present / imagen super no presente)"
        fi
        echo "  OK — nothing written / no se escribio nada"
        exit 0 ;;
    5) echo "  bye / adios"; exit 0 ;;
    1|2|3) ;;
    *) echo "  invalid / invalida"; exit 1 ;;
esac

if [ -z "$SUPER" ] && [ "$OPT" != "3" ]; then
    echo
    echo "  ERROR: super image not found / no se encuentra la imagen super"
    echo "  Put super.simg in images/ (see README). / Pon super.simg en images/ (ver README)."
    exit 1
fi

# ----------------------------------------------------------------------------
# Plan
# ----------------------------------------------------------------------------
echo
msg plan
echo
if [ "$OPT" != "3" ]; then echo "    super            <- $SUPER"; fi
echo "    boot_a           <- images/boot_a.img"
echo "    init_boot_a      <- images/init_boot_a.img"
echo "    vendor_boot_a    <- images/vendor_boot_a.img"
echo "    dtbo_a           <- images/dtbo_a.img"
echo "    vbmeta_a         <- images/vbmeta_a.img"
echo "    vbmeta_system_a  <- images/vbmeta_system_a.img"
echo "    vbmeta_vendor_a  <- images/vbmeta_vendor_a.img"
echo
msg confirm
read -r ok2
if [ "$LANG_SEL" = "en" ]; then
    [ "$ok2" = "YES" ] || { echo; msg noaccept; exit 1; }
else
    [ "$ok2" = "SI" ] || { echo; msg noaccept; exit 1; }
fi
echo

# ----------------------------------------------------------------------------
# Flashear
# ----------------------------------------------------------------------------
if [ "$OPT" != "3" ]; then
    msg flashing
    echo "    super"
    "$FB" flash super "$SUPER" || { echo "  FAILED: super"; exit 1; }
fi

for p in boot_a init_boot_a vendor_boot_a dtbo_a vbmeta_a vbmeta_system_a vbmeta_vendor_a; do
    f="$IMG/$p.img"
    [ -f "$f" ] || { printf "  $(msg badfile)\n" "$f"; exit 1; }
    msg flashing
    echo "    $p"
    "$FB" flash "$p" "$f" || { echo "  FAILED: $p"; exit 1; }
done

if [ "$OPT" = "1" ]; then
    echo
    msg wiping
    "$FB" -w || true
fi

echo
msg reboot
"$FB" reboot || true
echo
msg done
echo
msg onlyroot
echo
