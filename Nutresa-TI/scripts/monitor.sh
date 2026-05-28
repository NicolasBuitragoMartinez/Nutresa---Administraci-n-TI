#!/usr/bin/env bash
# Nutresa - monitor.sh
# Versión: Mejorada para producción
# Objetivo: Reporte de sistema para administradores. No eliminar funcionalidades.

set -o pipefail
set -o nounset
# Nota: no forzamos `set -e` porque algunos comandos pueden fallar legítimamente

readonly SCRIPT_NAME="nutresa_monitor"
readonly DEFAULT_LOG="/var/log/nutresa_monitor.log"
LOG="${DEFAULT_LOG}"
FECHA_FMT() { date +"%Y-%m-%dT%H:%M:%S%z"; }

# ANSI colors (only when outputting to a TTY)
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

# Commands required for various checks
REQUIRED_CMDS=(date top free df docker lvs systemctl awk grep cat uptime)

usage() {
	cat <<EOF
Usage: $0 [--log /path/to/log]
	--log   Custom log path (default: ${DEFAULT_LOG})
EOF
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		--log) LOG="$2"; shift 2 ;;
		-h|--help) usage; exit 0 ;;
		*) break ;;
	esac
done

ensure_log() {
	local dir
	dir=$(dirname "${LOG}")
	if [ ! -d "${dir}" ]; then
		mkdir -p "${dir}" || {
			# fallback to user local
			LOG="$HOME/.local/share/${SCRIPT_NAME}.log"
			mkdir -p "$(dirname "${LOG}")"
		}
	fi
	touch "${LOG}" || {
		LOG="$HOME/.local/share/${SCRIPT_NAME}.log"
		touch "${LOG}" || {
			echo "${C_ERR}ERROR:${C_RESET} No se puede escribir el log en ${LOG}" >&2
			exit 2
		}
	}
}

log() {
	local level="$1"; shift
	local ts
	ts=$(FECHA_FMT)
	printf '[%s] %-6s %s\n' "${ts}" "${level}" "$*" >> "${LOG}"
}

echo_color() {
	local clr="$1"; shift
	printf "%b%s%b\n" "${clr}" "$*" "${C_RESET}"
}

require_command() {
	local cmd="$1"
	if ! command -v "${cmd}" >/dev/null 2>&1; then
		echo_color "${C_WARN}" "WARN: '${cmd}' no está disponible en PATH. Algunas secciones pueden omitirse."
		log WARN "Comando faltante: ${cmd}"
		return 1
	fi
	return 0
}

require_commands_all() {
	local miss=0
	for c in "${REQUIRED_CMDS[@]}"; do
		if ! require_command "${c}"; then miss=1; fi
	done
	return ${miss}
}

trap_handler() {
	local code=${1:-0}
	log INFO "Script terminado con codigo ${code}"
	echo_color "${C_INFO}" "Finalizado: $(FECHA_FMT) - salida ${code}"
	exit ${code}
}

trap 'trap_handler $?' EXIT

ensure_log

log INFO "INICIO REPORTE DE MONITOREO"
log INFO "Log activo: ${LOG}"

echo_color "${C_BOLD}${C_INFO}" "========================================"
echo_color "${C_BOLD}${C_INFO}" "[$(FECHA_FMT)] REPORTE DE MONITOREO"
echo_color "${C_BOLD}${C_INFO}" "========================================"

# --- Helper: CPU usage (instant, calculado) ---
get_cpu_usage() {
	# lee /proc/stat dos veces para calcular uso en intervalo corto
	local -a cpu1 cpu2
	read -r _ cpu1user cpu1nice cpu1system cpu1idle cpu1iowait cpu1irq cpu1softirq cpu1steal < /proc/stat
	sleep 0.2
	read -r _ cpu2user cpu2nice cpu2system cpu2idle cpu2iowait cpu2irq cpu2softirq cpu2steal < /proc/stat
	local user=$((cpu2user - cpu1user))
	local nice=$((cpu2nice - cpu1nice))
	local system=$((cpu2system - cpu1system))
	local idle=$((cpu2idle - cpu1idle))
	local iowait=$((cpu2iowait - cpu1iowait))
	local total=$((user + nice + system + idle + iowait + cpu2irq - cpu1irq + cpu2softirq - cpu1softirq + cpu2steal - cpu1steal))
	if [ "${total}" -le 0 ]; then
		echo "N/A"
		return
	fi
	local busy=$((total - idle))
	awk -v b="${busy}" -v t="${total}" 'BEGIN { printf("%.1f%%", (b/t)*100) }'
}

# --- Memory ---
report_memory() {
	echo_color "${C_BOLD}" "--- MEMORIA ---"
	log INFO "--- MEMORIA ---"
	if require_command free; then
		free -h | sed 's/^/  /' | tee -a "${LOG}"
	else
		log WARN "free no disponible"
	fi
}

# --- CPU ---
report_cpu() {
	echo_color "${C_BOLD}" "--- CPU ---"
	log INFO "--- CPU ---"
	if require_command top; then
		# preserve original 'top' output for compatibility
		top -bn1 | head -n5 | sed 's/^/  /' | tee -a "${LOG}"
	fi
	local cpu_usage
	cpu_usage=$(get_cpu_usage || echo "N/A")
	printf "Uso CPU (calculo): %s\n" "${cpu_usage}" | tee -a "${LOG}"
	# alerta básica
	if [[ "${cpu_usage}" != "N/A" ]]; then
		local val
		val=$(printf "%s" "${cpu_usage}" | tr -d ' %')
		if (( ${val%%.*} >= 85 )); then
			echo_color "${C_WARN}" "ALERTA: Uso de CPU alto: ${cpu_usage}"
			log WARN "CPU alto: ${cpu_usage}"
		fi
	fi
}

# --- Disk ---
report_disk() {
	echo_color "${C_BOLD}" "--- DISCO ---"
	log INFO "--- DISCO ---"
	if require_command df; then
		df -hP | sed 's/^/  /' | tee -a "${LOG}"
		# buscar particiones con >85%
		df -hP --output=pcent,target | tail -n +2 | awk '{gsub(/%/,"",$1); if($1+0>=85) printf "ALERTA: Uso disco %s%% en %s\n", $1, $2}' | while IFS= read -r line; do
			echo_color "${C_WARN}" "${line}"
			log WARN "${line}"
		done
	fi
}

# --- RAID ---
report_raid() {
	echo_color "${C_BOLD}" "--- RAID ---"
	log INFO "--- RAID ---"
	if [ -r /proc/mdstat ]; then
		sed 's/^/  /' /proc/mdstat | tee -a "${LOG}"
	else
		log WARN "/proc/mdstat no accesible"
	fi
}

# --- LVM ---
report_lvm() {
	echo_color "${C_BOLD}" "--- LVM ---"
	log INFO "--- LVM ---"
	if require_command lvs; then
		if [ "$(id -u)" -ne 0 ]; then
			if command -v sudo >/dev/null 2>&1; then
				sudo lvs 2>&1 | sed 's/^/  /' | tee -a "${LOG}" || true
			else
				lvs 2>&1 | sed 's/^/  /' | tee -a "${LOG}" || true
			fi
		else
			lvs 2>&1 | sed 's/^/  /' | tee -a "${LOG}" || true
		fi
	fi
}

# --- Uptime ---
report_uptime() {
	echo_color "${C_BOLD}" "--- UPTIME ---"
	log INFO "--- UPTIME ---"
	if require_command uptime; then
		uptime -p | sed 's/^/  /' | tee -a "${LOG}"
	fi
}

# --- Temperatura ---
report_temperature() {
	echo_color "${C_BOLD}" "--- TEMPERATURA ---"
	log INFO "--- TEMPERATURA ---"
	if require_command sensors; then
		sensors | sed 's/^/  /' | tee -a "${LOG}"
	else
		# Intentar /sys/class/thermal
		if compgen -G "/sys/class/thermal/thermal_zone*/temp" >/dev/null; then
			for f in /sys/class/thermal/thermal_zone*/temp; do
				local val
				val=$(cat "${f}" 2>/dev/null || echo "")
				if [ -n "${val}" ]; then
					# algunos sys usan millidegree
					if [ ${#val} -gt 3 ]; then
						printf "  %s: %.1f°C\n" "${f##*/}" "$(awk -v v=${val} 'BEGIN { printf "%.1f", v/1000 }')" | tee -a "${LOG}"
					else
						printf "  %s: %s\n" "${f##*/}" "${val}" | tee -a "${LOG}"
					fi
				fi
			done
		else
			log INFO "No hay sensores de temperatura disponibles"
		fi
	fi
}

# --- Red ---
report_network() {
	echo_color "${C_BOLD}" "--- RED (interfaces) ---"
	log INFO "--- RED ---"
	if [ -r /proc/net/dev ]; then
		awk 'NR>2 { gsub(/:/,"",$1); rx=$2; tx=$10; printf("  %-8s RX=%10s TX=%10s\n", $1, rx, tx) }' /proc/net/dev | sort -k2 -n -r | sed 's/^/  /' | tee -a "${LOG}"
	fi
}

# --- Servicios críticos ---
report_services() {
	echo_color "${C_BOLD}" "--- SERVICIOS CRÍTICOS ---"
	log INFO "--- SERVICIOS CRÍTICOS ---"
	local services=(docker nginx mysql)
	for s in "${services[@]}"; do
		if command -v systemctl >/dev/null 2>&1; then
			local st
			st=$(systemctl is-active "${s}" 2>/dev/null || echo "unknown")
			printf "  %-10s %s\n" "${s}" "${st}" | tee -a "${LOG}"
			if [ "${st}" != "active" ]; then
				log WARN "Servicio ${s} estado: ${st}"
			else
				log INFO "Servicio ${s} activo"
			fi
		else
			log WARN "systemctl no disponible para consultar servicio ${s}"
		fi
	done
}

# --- Docker / Contenedores ---
report_docker() {
	echo_color "${C_BOLD}" "--- CONTENEDORES DOCKER ---"
	log INFO "--- CONTENEDORES DOCKER ---"
	if require_command docker; then
		docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | sed 's/^/  /' | tee -a "${LOG}"
		# intentar extraer health status si existe
		docker ps -q | while read -r id; do
			local name
			name=$(docker inspect --format '{{.Name}}' "${id}" 2>/dev/null | sed 's#/##') || continue
			local health
			health=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "${id}" 2>/dev/null || echo "none")
			if [ "${health}" != "none" ]; then
				printf "  %-20s health=%s\n" "${name}" "${health}" | tee -a "${LOG}"
			fi
		done
	fi
}

# --- Sumario final ---
report_summary() {
	echo_color "${C_BOLD}${C_INFO}" "--- RESUMEN ---"
	log INFO "--- RESUMEN ---"
	printf "Generado: %s\n" "$(FECHA_FMT)" | tee -a "${LOG}"
}

# Ejecutar reportes (manteniendo compatibilidad con el script original)
report_cpu
report_memory
report_disk
report_raid
report_docker
report_lvm
report_uptime
report_temperature
report_network
report_services
report_summary

echo "" >> "${LOG}"
log INFO "FIN REPORTE DE MONITOREO"

exit 0