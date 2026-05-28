#!/usr/bin/env bash
# Nutresa - deploy.sh
# Versión mejorada: validaciones, rollback básico, healthchecks y logs profesionales

set -o pipefail
set -o nounset
set -o errexit

readonly SCRIPT_NAME="nutresa_deploy"
readonly PROYECTO="/home/adminnutresa/nutresa-ti"
readonly DEFAULT_LOG="/var/log/nutresa_deploy.log"
LOG="${DEFAULT_LOG}"
FECHA_FMT() { date +"%Y-%m-%dT%H:%M:%S%z"; }

if [ -t 1 ]; then
	readonly C_RESET="\e[0m"
	readonly C_BOLD="\e[1m"
	readonly C_OK="\e[32m"
	readonly C_WARN="\e[33m"
	readonly C_ERR="\e[31m"
	readonly C_INFO="\e[36m"
else
	readonly C_RESET=""
	readonly C_BOLD=""
	readonly C_OK=""
	readonly C_WARN=""
	readonly C_ERR=""
	readonly C_INFO=""
fi

usage() { echo "Usage: $0 [--project PATH] [--log PATH]"; }
while [ "$#" -gt 0 ]; do
	case "$1" in
		--project) PROYECTO="$2"; shift 2;;
		--log) LOG="$2"; shift 2;;
		-h|--help) usage; exit 0;;
		*) break;;
	esac
done

ensure_log() {
	local dir
	dir=$(dirname "${LOG}")
	mkdir -p "${dir}" || true
	touch "${LOG}" || {
		LOG="$HOME/.local/share/${SCRIPT_NAME}.log"
		mkdir -p "$(dirname "${LOG}")" || true
		touch "${LOG}" || true
	}
}

log() { local level="$1"; shift; printf '[%s] %-6s %s\n' "$(FECHA_FMT)" "${level}" "$*" >> "${LOG}"; }
echo_color() { local clr="$1"; shift; printf "%b%s%b\n" "${clr}" "$*" "${C_RESET}"; }

trap 'echo_color "${C_ERR}" "Interrumpido"; log ERROR "Interrumpido"; exit 130' INT TERM

ensure_log
log INFO "INICIO DESPLIEGUE"
log INFO "Proyecto: ${PROYECTO}"

require_command() { command -v "$1" >/dev/null 2>&1 || { echo_color "${C_ERR}" "Falta '$1' en PATH"; log ERROR "Falta $1"; exit 2; }; }
require_command docker
require_command docker-compose
require_command ss || true

# Validar proyecto y docker-compose.yml
if [ ! -d "${PROYECTO}" ]; then
	echo_color "${C_ERR}" "ERROR: Proyecto no encontrado: ${PROYECTO}"
	log ERROR "Proyecto no encontrado: ${PROYECTO}"
	exit 3
fi
if [ ! -f "${PROYECTO}/docker-compose.yml" ]; then
	echo_color "${C_ERR}" "ERROR: docker-compose.yml no encontrado en ${PROYECTO}"
	log ERROR "docker-compose.yml no encontrado"
	exit 4
fi

pushd "${PROYECTO}" >/dev/null

# Guardar estado previo para rollback básico
PREV_PS="$(docker ps --format '{{.Names}}:{{.Image}}' 2>/dev/null || true)"
log INFO "Snapshot previo de contenedores guardado"

echo_color "${C_INFO}" "[$(FECHA_FMT)] Iniciando despliegue..."
log INFO "Iniciando despliegue"

echo_color "${C_INFO}" "[$(FECHA_FMT)] Bajando contenedores..."
log INFO "docker-compose down"
if ! docker-compose down >> "${LOG}" 2>&1; then
	echo_color "${C_WARN}" "Advertencia: fallo al bajar contenedores, se continúa"
	log WARN "docker-compose down falló"
fi

echo_color "${C_INFO}" "[$(FECHA_FMT)] Levantando contenedores (build)..."
log INFO "docker-compose up -d --build"
if ! docker-compose up -d --build >> "${LOG}" 2>&1; then
	echo_color "${C_ERR}" "ERROR: Falló 'docker-compose up -d --build'. Iniciando rollback básico"
	log ERROR "docker-compose up falló, intentando rollback"
	# rollback básico: intentar levantar sin rebuild con posibles imágenes previas
	docker-compose down >> "${LOG}" 2>&1 || true
	if docker-compose up -d --no-build >> "${LOG}" 2>&1; then
		echo_color "${C_WARN}" "Rollback aplicado: se levantaron contenedores sin reconstruir"
		log INFO "Rollback: up -d --no-build OK"
	else
		echo_color "${C_ERR}" "Rollback falló. Revisar ${LOG}"
		log ERROR "Rollback falló"
		popd >/dev/null
		exit 5
	fi
fi

# Verificar contenedores levantados y health checks
echo_color "${C_INFO}" "Verificando contenedores y health checks..."
log INFO "Verificando contenedores post-deploy"
docker ps --format '  {{.Names}}\t{{.Status}}' | tee -a "${LOG}"

# Comprobar health si aplica
docker ps -q | while read -r id; do
	health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${id}" 2>/dev/null || echo "none")
	name=$(docker inspect --format '{{.Name}}' "${id}" 2>/dev/null | sed 's#/##')
	if [ "${health}" = "unhealthy" ]; then
		echo_color "${C_WARN}" "ALERTA: Contenedor ${name} unhealthy"
		log WARN "Contenedor ${name} unhealthy"
	fi
done

# Validar puertos expuestos en host (basico)
if command -v ss >/dev/null 2>&1; then
	echo_color "${C_INFO}" "Validando puertos TCP escuchando (host)"
	ss -tln | sed 's/^/  /' | tee -a "${LOG}"
fi

echo_color "${C_OK}" "[$(FECHA_FMT)] Despliegue completado. Revisa ${LOG} para detalles."
log INFO "Despliegue completado"

popd >/dev/null

exit 0