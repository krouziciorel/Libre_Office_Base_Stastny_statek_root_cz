#!/usr/bin/env bash
# ==============================================================================
# Zálohovací skript pro projekt Šťastný statek (Evidence táborů)
# ==============================================================================

set -e

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
ZAL_DIR="${BASE_DIR}/ZAL"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
ARCHIVE_NAME="Zaloha_Stastny_statek_${TIMESTAMP}.zip"
DEST_ARCHIVE="${ZAL_DIR}/${ARCHIVE_NAME}"

cd "${BASE_DIR}"

mkdir -p "${ZAL_DIR}"

echo "=========================================================="
echo " Spouštím zálohování projektu Šťastný statek..."
echo " Čas: $(date '+%d.%m.%Y %H:%M:%S')"
echo "=========================================================="

# Detekce názvu databázového souboru (s diakritikou i bez)
DB_FILE="Šťastný_statek.odb"
if [ ! -f "${DB_FILE}" ]; then
    DB_FILE="Stastny_statek.odb"
fi

if [ ! -f "${DB_FILE}" ]; then
    echo "CHYBA: Soubor Šťastný_statek.odb ani Stastny_statek.odb nebyl nalezen v ${BASE_DIR}!"
    exit 1
fi

echo " Zálohuji databázi: ${DB_FILE}"

# Vytvoření ZIP archivu se všemi klíčovými komponentami:
# 1. Hlavní databáze (.odb)
# 2. Složka se šablonami Sablony/
# 3. Složka s vygenerovanými dokumenty Dokumenty/
# 4. Schéma a SQL skripty
zip -r "${DEST_ARCHIVE}" \
    "${DB_FILE}" \
    "Sablony" \
    "Dokumenty" \
    "schema.sql" \
    "testovaci_data.sql" \
    -x "Sablony/ZAL/*" "*.bak*" > /dev/null

# Zároveň vytvoříme přímou kopii aktuálního ODB do ZAL/latest/
mkdir -p "${ZAL_DIR}/latest"
cp -p "${DB_FILE}" "${ZAL_DIR}/latest/${DB_FILE}"

ARCHIVE_SIZE=$(du -h "${DEST_ARCHIVE}" | cut -f1)

echo " Záloha úspěšně vytvořena!"
echo " Archiv: ${DEST_ARCHIVE} (${ARCHIVE_SIZE})"
echo " Aktuální kopie: ${ZAL_DIR}/latest/${DB_FILE}"
echo "=========================================================="
