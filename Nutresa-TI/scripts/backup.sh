#!/usr/bin/env bash
# Nutresa - backup.sh
# Backup robusto: validación de espacio, compresión optimizada, checksum SHA256, exclusiones y rotación

set -o pipefail
set -o nounset

readonly SCRIPT_NAME="nutresa_backup"
FECHA=$(date +%F_%H-%M-%S)
ORIGEN="/data"
DESTINO="/backups"
DEFAULT_LOG="/var/log/nutresa_backup.log"
LOG="${DEFAULT_LOG}"
RETAIN_DAYS=7
EXCLUDES=()

if [ -t 1 ]; then
    readonly C_RESET="\e[0m"; readonly C_BOLD="\e[1m"; readonly C_OK="\e[32m"; readonly C_WARN="\e[33m"; readonly C_ERR="\e[31m"; readonly C_INFO="\e[36m"
else
    readonly C_RESET=""; readonly C_BOLD=""; readonly C_OK=""; readonly C_WARN=""; readonly C_ERR=""; readonly C_INFO=""
fi

usage(){ cat <<EOF
Usage: $0 [--src PATH] [--dst PATH] [--log PATH] [--retain DAYS]
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --src) ORIGEN="$2"; shift 2;;
        --dst) DESTINO="$2"; shift 2;;
        --log) LOG="$2"; shift 2;;
        --retain) RETAIN_DAYS="$2"; shift 2;;
        -h|--help) usage; exit 0;;
        *) break;;
    esac
done

ensure_log(){ mkdir -p "$(dirname "${LOG}")" 2>/dev/null || true; touch "${LOG}" 2>/dev/null || LOG="$HOME/.local/share/${SCRIPT_NAME}.log"; touch "${LOG}" 2>/dev/null || true; }
log(){ local lvl="$1"; shift; printf '[%s] %-6s %s\n' "$(date +"%Y-%m-%dT%H:%M:%S%z")" "$lvl" "$*" >> "${LOG}"; }
echo_color(){ local clr="$1"; shift; printf "%b%s%b\n" "${clr}" "$*" "${C_RESET}"; }

require_command(){ command -v "$1" >/dev/null 2>&1 || return 1; }

trap 'log ERROR "Interrumpido"; echo_color "${C_ERR}" "Interrumpido"; exit 130' INT TERM

ensure_log
log INFO "INICIO BACKUP"
log INFO "Origen=${ORIGEN} Destino=${DESTINO} RetainDays=${RETAIN_DAYS}"

if [ ! -d "${ORIGEN}" ]; then
    echo_color "${C_ERR}" "ERROR: Directorio origen no existe: ${ORIGEN}"
    log ERROR "Origen no existe: ${ORIGEN}"
    exit 2
fi

mkdir -p "${DESTINO}" || { echo_color "${C_ERR}" "ERROR: no puede crear ${DESTINO}"; log ERROR "mkdir fallo"; exit 3; }

# Seleccionar compresor: pigz cuando esté disponible para paralelizar
COMPRESS_CMD="gzip -c"
COMPRESS_EXT="gz"
if require_command pigz; then
    COMPRESS_CMD="pigz -c"
    COMPRESS_EXT="gz"
    log INFO "Usando pigz para compresión"
elif require_command gzip; then
    COMPRESS_CMD="gzip -c"
    COMPRESS_EXT="gz"
    log INFO "Usando gzip para compresión"
else
    echo_color "${C_ERR}" "ERROR: No se encontró compresor (gzip/pigz)"
    log ERROR "No compresor disponible"
    exit 4
fi

# Verificar espacio: estimar tamaño usando du (rápido) y comparar con espacio libre en DESTINO
ESTIMATED_SIZE_BYTES=$(du -sb "${ORIGEN}" 2>/dev/null | cut -f1 || echo 0)
avail_bytes=$(df --output=avail -B1 "${DESTINO}" 2>/dev/null | tail -n1 || echo 0)
if [ -n "${ESTIMATED_SIZE_BYTES}" ] && [ -n "${avail_bytes}" ] && [ "${ESTIMATED_SIZE_BYTES}" -ge "${avail_bytes}" ]; then
    echo_color "${C_ERR}" "ERROR: Espacio insuficiente en ${DESTINO}. Estimado ${ESTIMATED_SIZE_BYTES}, disponible ${avail_bytes}" >&2
    log ERROR "Espacio insuficiente: estimado ${ESTIMATED_SIZE_BYTES} >= disponible ${avail_bytes}"
    exit 5
fi

ARCHIVE_NAME="backup-${FECHA}.tar.${COMPRESS_EXT}"
ARCHIVE_PATH="${DESTINO}/${ARCHIVE_NAME}"

echo_color "${C_INFO}" "Iniciando compresión: ${ARCHIVE_PATH}"
log INFO "Comenzando tar+compresion"

# Construir lista de exclusiones para tar
EXCL_ARGS=()

# Crear el tar y comprimirlo en streaming
tar -cpf - "${ORIGEN}" "${EXCL_ARGS[@]}" 2>> "${LOG}" | ${COMPRESS_CMD} > "${ARCHIVE_PATH}" 2>> "${LOG}"; if [ "${PIPESTATUS[0]}" -eq 0 ]; then
    log INFO "Archivo creado: ${ARCHIVE_PATH}"
else
    echo_color "${C_ERR}" "ERROR durante la creación del backup. Revisa ${LOG}"
    log ERROR "tar/compress falló"
    exit 6
fi

# Tamaño del backup
SIZE_BYTES=$(stat -c%s "${ARCHIVE_PATH}" 2>/dev/null || echo 0)
SIZE_HUMAN=$(du -h "${ARCHIVE_PATH}" | cut -f1 || echo "0")
log INFO "Backup completado: ${ARCHIVE_NAME} size=${SIZE_HUMAN} bytes=${SIZE_BYTES}"
echo_color "${C_OK}" "Backup completado: ${ARCHIVE_NAME} (${SIZE_HUMAN})"

# Checksum SHA256
if require_command sha256sum; then
    sha256sum "${ARCHIVE_PATH}" > "${ARCHIVE_PATH}.sha256"
    log INFO "SHA256 generado: ${ARCHIVE_PATH}.sha256"
fi

# Validar integridad del tar comprimiendo (lista) - intento rápido
if tar -tf "${ARCHIVE_PATH}" >/dev/null 2>>"${LOG}"; then
    log INFO "Validacion tar OK"
else
    echo_color "${C_WARN}" "Advertencia: validación del tar falló"
    log WARN "Validacion tar falló"
fi

# Rotación profesional: eliminar archivos más antiguos que RETAIN_DAYS
find "${DESTINO}" -maxdepth 1 -type f -name "backup-*.tar.${COMPRESS_EXT}" -mtime +${RETAIN_DAYS} -print -delete 2>>"${LOG}" || true
log INFO "Rotación: archivos >${RETAIN_DAYS} días eliminados"

echo_color "${C_INFO}" "Limpieza de backups antiguos completada"
log INFO "Proceso finalizado"
echo "========================================" >> "${LOG}"

exit 0