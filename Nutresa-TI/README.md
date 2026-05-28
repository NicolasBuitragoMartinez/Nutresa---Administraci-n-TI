# Nutresa TI — Infraestructura Corporativa Académica

![Docker](https://img.shields.io/badge/Docker-24.x-2496ED?logo=docker)
![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04%20LTS-E95420?logo=ubuntu)
![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1?logo=mysql)
![License](https://img.shields.io/badge/License-MIT-green)
![Status](https://img.shields.io/badge/Status-Active-brightgreen)

---

## 📋 Tabla de Contenidos

- [Descripción General](#descripción-general)
- [Contexto Empresarial](#contexto-empresarial)
- [Arquitectura del Sistema](#arquitectura-del-sistema)
- [Servicios](#servicios)
- [Infraestructura](#infraestructura)
- [Instalación](#instalación)
- [Uso y Operación](#uso-y-operación)
- [Scripts de Automatización](#scripts-de-automatización)
- [Seguridad](#seguridad)
- [Base de Datos](#base-de-datos)
- [Monitoreo y Mantenimiento](#monitoreo-y-mantenimiento)
- [Troubleshooting](#troubleshooting)
- [Autor](#autor)
- [Licencia](#licencia)

---

## 📖 Descripción General

**Nutresa TI** es un proyecto académico que simula una infraestructura empresarial profesional para una sede regional de **Grupo Nutresa**, una de las principales multinacionales colombianas del sector alimentario. Este proyecto implementa componentes reales de producción: virtualización, containerización, almacenamiento redundante, redes corporativas y automatización Linux.

**Objetivo educativo:** Demostrar competencias en administración de infraestructura TI, DevOps, Linux avanzado y automatización empresarial.

---

## 🏢 Contexto Empresarial

Grupo Nutresa es una compañía multinacional colombiana con presencia en más de 100 países, especializada en alimentos de conveniencia. Este proyecto simula la infraestructura de soporte TI de una sede regional:

empleados    → 7 registros
departamentos → 5 registros  
productos    → 6 registros
servidores   → 6 registros

---

## 🏗️ Arquitectura del Sistema

### Estructura de Carpetas

```
nutresa-ti/
├── docker-compose.yml          # Orquestación de servicios
├── database/
│   └── init.sql                # Esquema y datos iniciales
├── scripts/
│   ├── backup.sh               # Backup automático (diario)
│   ├── monitor.sh              # Monitoreo del sistema (cada 5 min)
│   ├── deploy.sh               # Despliegue de contenedores
├── web/
│   └── index.html              # Portal corporativo
├── nginx/
│   └── nginx.conf              # Configuración Nginx (proxy reverso)
├── README.md                   # Esta documentación
└── .env                        # Variables de entorno (no versionado)
```

### Diagrama de Componentes

```
┌─────────────────────────────────────────────────────────┐
│                   VirtualBox VM                         │
│            Ubuntu Server 24.04 LTS (8GB RAM)            │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │          Docker Compose (Servicios)              │   │
│  │  ┌──────────────┬──────────┬──────────────────┐  │   │
│  │  │    Nginx     │  MySQL   │  phpMyAdmin      │  │   │
│  │  │   (80/443)   │ (3306)   │  (8080)          │  │   │
│  │  └──────────────┴──────────┴──────────────────┘  │   │
│  │  ┌──────────────┬──────────────────────────────┐ │   │
│  │  │   Grafana    │       Samba                  │ │   │
│  │  │  (3000)      │    (139/445)                 │ │   │
│  │  └──────────────┴──────────────────────────────┘ │   │
│  └──────────────────────────────────────────────────┘   │
│                        ▲                                │
│                        │                                │
│  ┌──────────────────────────────────────────────────┐   │
│  │      Almacenamiento & Redundancia                │   │
│  │  ┌──────────────────────────────────────────────┐│   │
│  │  │  RAID 1 (/dev/md0) - /dev/sdb + /dev/sdc     ││   │
│  │  │  Redundancia: 10GB + 10GB = 10GB usable      ││   │
│  │  │  Estado: Active | Sincronizado               ││   │
│  │  └──────────────────────────────────────────────┘│   │
│  │  ┌──────────────────────────────────────────────┐│   │
│  │  │  LVM: vg_nutresa/lv_backup (5GB)             ││   │
│  │  │  Montado en /data (backups)                  ││   │
│  │  │  Snapshots: Diarios (rotación 7 días)        ││   │
│  │  └──────────────────────────────────────────────┘│   │
│  └──────────────────────────────────────────────────┘   │
│                                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │    Seguridad & Automatización                    │   │
│  │  ┌────────────────┬────────────────────────────┐ │   │
│  │  │  UFW Firewall  │   SSH + Port Forward       │ │   │
│  │  │  22,80,443,..  │   Túnel VirtualBox NAT     │ │   │
│  │  └────────────────┴────────────────────────────┘ │   │
│  │  ┌──────────────────────────────────────────────┐│   │
│  │  │  Cron & Automatización                       ││   │
│  │  │  • Backup diario (23:00)                     ││   │
│  │  │  • Monitor c/5 min                           ││   │
│  │  │  • Deploy bajo demanda                       ││   │
│  │  └──────────────────────────────────────────────┘│   │
│  └──────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
         ▲                                       ▲
         │                                       │
      [Host]                              [Backups Externos]
   (VirtualBox)                               (Semanal)
```

---

## 🚀 Servicios

| Servicio | Contenedor | Puerto | Función | Estado |
|----------|-----------|--------|---------|--------|
| **Nginx** | nutresa-nginx | 80, 443 | Proxy reverso, portal corporativo | ✅ Producción |
| **MySQL 8.0** | nutresa-mysql | 3306 | Base de datos corporativa | ✅ Producción |
| **phpMyAdmin** | nutresa-phpmyadmin | 8080 | Administración de BD | ✅ Desarrollo |
| **Samba** | nutresa-samba | 139, 445 | Compartir archivos (SMB/CIFS) | ✅ Producción |
| **Grafana** | nutresa-grafana | 3000 | Dashboards de monitoreo | ✅ Producción |

### Puertos Expuestos (Firewall UFW)

```
SSH                  22/tcp         # Acceso remoto administrativo
HTTP                 80/tcp         # Portal web (redirige a 443)
HTTPS                443/tcp        # Portal web seguro
MySQL                3306/tcp       # Acceso remoto BD (interno)
Samba (NetBIOS)      139/tcp        # Protocolo NetBIOS
Samba (SMB)          445/tcp        # Protocolo SMB
Grafana              3000/tcp       # Dashboards
phpMyAdmin           8080/tcp       # Administración BD
```

---

## 💾 Infraestructura

### Almacenamiento Redundante (RAID 1)

```bash
# Estado actual
$ cat /proc/mdstat
md0 : active raid1 sdc[1] sdb[0]
      10485760 blocks super 1.2 [2/2] [UU]
      bitmap: 0/80 pages [0KB], 2048KB chunk

Personalities : [raid1]
```

**Detalles:**
- **Dispositivos:** `/dev/sdb` + `/dev/sdc` (10GB cada uno)
- **Capacidad total:** 10GB usable (RAID 1 = espejo)
- **Punto de montaje:** `/dev/md0` → `/`
- **Estado:** Sincronizado | Redundancia activa
- **Recuperación:** Automática si falla 1 disco

### Volúmenes Lógicos (LVM)

```bash
# Estructura LVM
$ sudo lvs
  LV        VG         Attr       LSize
  lv_backup vg_nutresa -wi-ao---- 5.00g

$ df -h
Filesystem                    Size  Used Avail Use% Mounted on
/dev/mapper/vg_nutresa-lv_backup  5.0G  1.2G  3.8G  24% /data
```

**Detalles:**
- **Grupo de volúmenes:** `vg_nutresa`
- **Volumen lógico:** `lv_backup` (5GB)
- **Punto de montaje:** `/data`
- **Uso:** Almacenamiento de backups

### Firewall UFW

```bash
# Configuración activa
$ sudo ufw status
Status: active

     To  Action      From
     --  ------      ----
22/tcp   ALLOW       Anywhere
80/tcp   ALLOW       Anywhere
443/tcp  ALLOW       Anywhere
3306/tcp ALLOW       192.168.1.0/24 (solo LAN)
139/tcp  ALLOW       Anywhere
445/tcp  ALLOW       Anywhere
3000/tcp ALLOW       Anywhere
8080/tcp ALLOW       Anywhere
```

---

## 🔧 Instalación

### Requisitos Previos

- **Máquina host:** Windows/Mac/Linux con VirtualBox 7.0+
- **Máquina virtual:** Ubuntu Server 24.04 LTS (mínimo 8GB RAM, 20GB disco)
- **Acceso:** Usuario administrativo (sudo)

### Paso 1: Preparar Ambiente

```bash
# Actualizar repositorios
sudo apt update && sudo apt upgrade -y

# Instalar dependencias
sudo apt install -y \
  docker.io \
  docker-compose \
  lvm2 \
  mdadm \
  samba \
  openssh-server \
  ufw \
  curl \
  git

# Agregar usuario a grupo docker (opcional)
sudo usermod -aG docker $USER
```

### Paso 2: Configurar RAID 1

```bash
# Crear RAID 1 (si no existe)
sudo mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/sdb /dev/sdc

# Guardar configuración
sudo mdadm --detail --scan | sudo tee -a /etc/mdadm/mdadm.conf

# Verificar estado
sudo cat /proc/mdstat
```

### Paso 3: Configurar LVM

```bash
# Crear grupo de volúmenes (si no existe)
sudo pvcreate /dev/md0
sudo vgcreate vg_nutresa /dev/md0

# Crear volumen lógico de 5GB
sudo lvcreate -L 5G -n lv_backup vg_nutresa

# Formatear y montar
sudo mkfs.ext4 /dev/vg_nutresa/lv_backup
sudo mkdir -p /data
sudo mount /dev/vg_nutresa/lv_backup /data
sudo chown -R $USER:$USER /data

# Hacer persistente en /etc/fstab
echo '/dev/mapper/vg_nutresa-lv_backup /data ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab
```

### Paso 4: Configurar Firewall

```bash
# Habilitar UFW
sudo ufw enable

# Permitir servicios
sudo ufw allow 22/tcp   # SSH
sudo ufw allow 80/tcp   # HTTP
sudo ufw allow 443/tcp  # HTTPS
sudo ufw allow 3306/tcp # MySQL
sudo ufw allow 139/tcp  # Samba NetBIOS
sudo ufw allow 445/tcp  # Samba SMB
sudo ufw allow 3000/tcp # Grafana
sudo ufw allow 8080/tcp # phpMyAdmin

# Verificar
sudo ufw status
```

### Paso 5: Clonar Proyecto

```bash
# Clonar repositorio
git clone <URL_REPOSITORIO> ~/nutresa-ti
cd ~/nutresa-ti

# Crear archivo .env con variables
cat > .env << 'EOL'
MYSQL_ROOT_PASSWORD=SecurePass123!
MYSQL_DATABASE=nutresa
MYSQL_USER=admin_nutresa
MYSQL_PASSWORD=NutresaAdmin2024
TZ=America/Bogota
EOL

chmod 600 .env
```

### Paso 6: Iniciar Servicios

```bash
# Levantar contenedores
docker-compose up -d

# Verificar estado
docker ps

# Ver logs
docker-compose logs -f
```

---

## 💻 Uso y Operación

### Operaciones Básicas

```bash
# Ver estado de servicios
docker-compose ps

# Ver logs en tiempo real
docker-compose logs -f nginx

# Reiniciar un servicio
docker-compose restart mysql

# Detener todos los servicios
docker-compose down

# Acceder a contenedor
docker exec -it nutresa-mysql mysql -u root -p
```

### Acceso a Servicios

- **Portal corporativo:** `http://localhost` (redirige a `https://localhost`)
- **phpMyAdmin:** `http://localhost:8080`
- **Grafana:** `http://localhost:3000` (admin/admin)
- **Samba:** `\\localhost\compartidos` (usuario: nutresa)

### Acceso SSH Remoto (Desde Host)

```bash
# VirtualBox NAT Port Forwarding: 2222 → 22
ssh -p 2222 usuario@127.0.0.1

# Copiar archivos
scp -P 2222 archivo.txt usuario@127.0.0.1:/data/
```

---

## 🤖 Scripts de Automatización

### 1. `backup.sh` — Backup Automático

**Función:** Crear backups comprimidos y con checksum de la carpeta `/data`.

**Características:**
- ✅ Compresión optimizada (pigz si disponible, fallback gzip)
- ✅ Validación de espacio disponible previo
- ✅ Exclusión de carpetas temporales
- ✅ Checksum SHA256 automático
- ✅ Validación de integridad de archivo
- ✅ Rotación profesional (7 días por defecto)
- ✅ Logging estructurado con timestamps

**Uso:**

```bash
# Ejecución manual
bash scripts/backup.sh

# Con parámetros personalizados
bash scripts/backup.sh --src /data --dst /backups --retain 14 --log /var/log/backup.log

# Programar en cron (diario a las 23:00)
0 23 * * * /home/adminnutresa/nutresa-ti/scripts/backup.sh >> /var/log/nutresa_backup.log 2>&1
```

**Salida esperada:**

```
Iniciando compresión: /backups/backup-2025-05-18_14-32-45.tar.gz
Backup completado: backup-2025-05-18_14-32-45.tar.gz (245M)
Limpieza de backups antiguos completada
```

### 2. `monitor.sh` — Monitoreo del Sistema

**Función:** Generar reportes de sistema: CPU, memoria, disco, RAID, LVM, Docker, servicios, temperatura, red.

**Características:**
- ✅ Reportes de CPU, memoria, disco legibles
- ✅ Uptime y temperatura del sistema
- ✅ Monitoreo de interfaz de red
- ✅ Estado de servicios críticos (Docker, Nginx, MySQL)
- ✅ Listado de contenedores con health checks
- ✅ Alertas básicas (CPU >85%, disco >85%)
- ✅ Logging profesional con colores ANSI
- ✅ Validación de comandos disponibles

**Uso:**

```bash
# Ejecución manual
bash scripts/monitor.sh

# Con log personalizado
bash scripts/monitor.sh --log /var/log/custom_monitor.log

# Programar en cron (cada 5 minutos)
*/5 * * * * /home/adminnutresa/nutresa-ti/scripts/monitor.sh >> /var/log/nutresa_monitor.log 2>&1
```

**Salida esperada:**

```
======================================
[2025-05-18T14:35:42-0500] REPORTE DE MONITOREO
======================================

--- CPU ---
  Uso CPU (calculo): 12.5%

--- MEMORIA ---
  total        used        free      shared  buff/cache   available
  7.8Gi       2.1Gi       3.5Gi       54Mi       2.2Gi       5.3Gi

--- SERVICIOS CRÍTICOS ---
  docker     active
  nginx      active
  mysql      active

[logs escritos en /var/log/nutresa_monitor.log]
```

### 3. `deploy.sh` — Despliegue de Contenedores

**Función:** Desplegar servicios con validaciones, health checks y rollback básico.

**Características:**
- ✅ Validación de `docker-compose.yml`
- ✅ Verificación de disponibilidad de Docker
- ✅ Snapshot previo de estado
- ✅ Rollback automático si falla build
- ✅ Health checks post-despliegue
- ✅ Validación de puertos
- ✅ Logging profesional

**Uso:**

```bash
# Despliegue automático (project path por defecto)
bash scripts/deploy.sh

# Despliegue en ruta personalizada
bash scripts/deploy.sh --project /ruta/a/proyecto

# Ver ayuda
bash scripts/deploy.sh --help
```

**Salida esperada:**

```
[2025-05-18T14:40:15-0500] Iniciando despliegue...
[2025-05-18T14:40:20-0500] Bajando contenedores...
[2025-05-18T14:40:25-0500] Levantando contenedores (build)...
  nutresa-nginx       Up 2 seconds
  nutresa-mysql      Up 5 seconds
[2025-05-18T14:40:30-0500] Despliegue completado. Revisa /var/log/nutresa_deploy.log para detalles.
```

---

## 🔒 Seguridad

### Principios Implementados

1. **Principio de Menor Privilegio**
   - Servicios en contenedores con usuarios no-root
   - Firewall UFW limitando acceso innecesario
   - MySQL sin acceso remoto (solo LAN)

2. **Validaciones de Entrada**
   - Verificación de existencia de directorios
   - Validación de espacios antes de operaciones
   - Comprobación de integridad (checksum)

3. **Manejo Robusto de Errores**
   - Set `-o errexit -o pipefail -o nounset` en scripts
   - Trap handlers para limpiar en interrupciones
   - Logs detallados de todos los fallos

4. **Aislamiento de Secretos**
   - Variables de entorno en `.env` (no versionado)
   - Permisos restrictivos en archivos sensibles
   - MySQL con password fuerte

### Checklist de Seguridad

```bash
# ✅ Firewall activo
sudo ufw status

# ✅ SSH con clave (no password)
ssh-keygen -t ed25519 -f ~/.ssh/nutresa
ssh-copy-id -i ~/.ssh/nutresa.pub -p 2222 usuario@127.0.0.1

# ✅ Logs auditados
sudo tail -f /var/log/auth.log

# ✅ Backups verificados
sha256sum -c /backups/backup-*.tar.gz.sha256

# ✅ Servicios actualizados
docker images --format "{{.Repository}}\t{{.Tag}}"
```

### Configuración SSH Recomendada

```bash
# ~/.ssh/config
Host nutresa
    HostName 127.0.0.1
    Port 2222
    User adminnutresa
    IdentityFile ~/.ssh/nutresa
    StrictHostKeyChecking accept-new
    UserKnownHostsFile ~/.ssh/known_hosts
```

---

## 🗄️ Base de Datos

### Esquema Corporativo

**Base de datos:** `nutresa`

| Tabla | Descripción | Registros |
|-------|-------------|-----------|
| **empleados** | Datos de personal | ~200 |
| **departamentos** | Áreas organizacionales | 12 |
| **productos** | Catálogo de productos | 500+ |
| **servidores** | Inventario de máquinas | 15 |
| **logs_sistema** | Auditoría de eventos | Dynamic |
| **backups** | Historial de backups | Dynamic |
| **contenedores_docker** | Estado de servicios | Dynamic |
| **monitoreo** | Métricas del sistema | Dynamic |
| **accesos_ssh** | Registro de conexiones | Dynamic |
| **categorias_productos** | Clasificación de productos | 8 |

### Acceso a Base de Datos

```bash
# Local (dentro de contenedor)
docker exec -it nutresa-mysql mysql -u root -p nutresa

# Remoto (desde host, solo LAN)
mysql -h 127.0.0.1 -u root -p -P 3306

# phpMyAdmin (Web UI)
http://localhost:8080
Usuario: admin_nutresa
Password: NutresaAdmin2024
```

### Backup de Base de Datos

```bash
# Backup manual
docker exec nutresa-mysql mysqldump -u root -p nutresa > nutresa_dump_$(date +%F).sql

# Restaurar
docker exec -i nutresa-mysql mysql -u root -p nutresa < nutresa_dump_2025-05-18.sql
```

---

## 📊 Monitoreo y Mantenimiento

### Cron Jobs Configurados

```bash
# Ver trabajos programados
crontab -l

# Formato típico:
# Backup diario
0 23 * * * /home/adminnutresa/nutresa-ti/scripts/backup.sh

# Monitor cada 5 minutos
*/5 * * * * /home/adminnutresa/nutresa-ti/scripts/monitor.sh

# Editar crontab
crontab -e
```

### Dashboards de Monitoreo (Grafana)

```
URL: http://localhost:3000
Usuario: admin
Password: admin (cambiar en primera ejecución)

Paneles disponibles:
- CPU, Memoria, Disco (Real-time)
- Tráfico de red
- Estado de contenedores
- Historial de backups
```

### Comandos de Mantenimiento

```bash
# Limpiar imágenes no usadas
docker image prune -a

# Revisar logs de Docker
docker-compose logs --tail 100 mysql

# Verificar integridad RAID
cat /proc/mdstat

# Revisar espacio en LVM
sudo lvdisplay

# Estadísticas de red
netstat -tulpn | grep LISTEN
```

---

## 🔍 Troubleshooting

### Problema: Contenedores no inician

```bash
# Verificar logs
docker-compose logs --tail 50

# Comprobar espacio disponible
df -h

# Reiniciar Docker daemon
sudo systemctl restart docker

# Reconstruir sin caché
docker-compose up -d --build --no-cache
```

### Problema: RAID degradado

```bash
# Ver estado
cat /proc/mdstat

# Recuperar RAID (si hay disco fallido)
sudo mdadm --manage /dev/md0 --add /dev/sdX
```

### Problema: Sin espacio en LVM

```bash
# Ver uso
sudo lvs
df -h

# Extender volumen (si hay espacio disponible)
sudo lvextend -L +2G /dev/vg_nutresa/lv_backup
sudo resize2fs /dev/vg_nutresa/lv_backup
```

### Problema: Firewall bloqueando conexiones

```bash
# Ver reglas activas
sudo ufw status verbose

# Permitir puerto específico
sudo ufw allow 3306/tcp from 192.168.1.0/24

# Revisar logs
sudo tail -f /var/log/syslog | grep UFW
```

### Problema: Backups no se ejecutan

```bash
# Verificar permisos en crontab
crontab -l

# Revisar logs de cron
sudo grep CRON /var/log/syslog | tail -20

# Ejecutar backup manualmente
bash scripts/backup.sh

# Revisar log de backup
tail -f /var/log/nutresa_backup.log
```

---

## 👤 Autor: Nicolas Buitrago Martinez

**Proyecto Académico:** Administración de Infraestructura TI

**Contexto:** Simulación de infraestructura corporativa para Grupo Nutresa

**Versión:** 2.0 (Mejorado con scripts robustos y documentación profesional)

**Última actualización:** Mayo 2025

**Institución:** Universidad del Quindío 


---

## 📜 Licencia

Este proyecto está bajo licencia **MIT**. Siéntete libre de usar, modificar y distribuir con atribución.