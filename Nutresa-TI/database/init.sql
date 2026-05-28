CREATE DATABASE IF NOT EXISTS nutresa
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE nutresa;

-- Base de datos corporativa Grupo Nutresa - Sede Regional TI
-- Tablas principales de gestión organizacional, productos e infraestructura TI.
-- Esta versión incluye integridad referencial, índices, timestamps y tablas de apoyo.

CREATE TABLE IF NOT EXISTS departamentos (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(100) NOT NULL,
    sede VARCHAR(100) NOT NULL,
    responsable VARCHAR(100) NOT NULL,
    presupuesto DECIMAL(15,2) NOT NULL DEFAULT 0.00 CHECK (presupuesto >= 0),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_departamentos_nombre (nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS empleados (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(100) NOT NULL,
    cargo VARCHAR(100) NOT NULL,
    departamento VARCHAR(100) NOT NULL,
    departamento_id INT NULL,
    email VARCHAR(150) NOT NULL,
    telefono VARCHAR(20),
    fecha_ingreso DATE NOT NULL,
    salario DECIMAL(12,2) NOT NULL DEFAULT 0.00 CHECK (salario >= 0),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_empleados_email (email),
    INDEX idx_empleados_departamento (departamento),
    INDEX idx_empleados_departamento_id (departamento_id),
    CONSTRAINT fk_empleados_departamento FOREIGN KEY (departamento_id)
        REFERENCES departamentos (id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS categorias_productos (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(100) NOT NULL,
    unidad_negocio VARCHAR(100) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_categorias_productos_nombre (nombre),
    INDEX idx_categorias_unidad_negocio (unidad_negocio)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS productos (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(150) NOT NULL,
    categoria VARCHAR(100) NOT NULL,
    categoria_id INT NULL,
    precio DECIMAL(10,2) NOT NULL DEFAULT 0.00 CHECK (precio >= 0),
    stock INT NOT NULL DEFAULT 0 CHECK (stock >= 0),
    unidad_negocio VARCHAR(100) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_productos_categoria (categoria),
    INDEX idx_productos_unidad_negocio (unidad_negocio),
    INDEX idx_productos_precio (precio),
    CONSTRAINT fk_productos_categoria FOREIGN KEY (categoria_id)
        REFERENCES categorias_productos (id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS servidores (
    id INT PRIMARY KEY AUTO_INCREMENT,
    hostname VARCHAR(100) NOT NULL,
    ip VARCHAR(45) NOT NULL,
    sistema_operativo VARCHAR(100) NOT NULL,
    rol VARCHAR(100) NOT NULL,
    departamento_id INT NULL,
    estado ENUM('activo', 'mantenimiento', 'inactivo', 'retirado') NOT NULL DEFAULT 'activo',
    ubicacion VARCHAR(100) NOT NULL DEFAULT 'Sede Regional',
    capacidad_memoria_gb TINYINT UNSIGNED DEFAULT 16,
    capacidad_cpu INT UNSIGNED DEFAULT 4,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_servidores_hostname (hostname),
    UNIQUE KEY uq_servidores_ip (ip),
    INDEX idx_servidores_estado (estado),
    INDEX idx_servidores_departamento_id (departamento_id),
    CONSTRAINT fk_servidores_departamento FOREIGN KEY (departamento_id)
        REFERENCES departamentos (id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tablas adicionales de infraestructura TI con auditoría y monitoreo.

CREATE TABLE IF NOT EXISTS logs_sistema (
    id INT PRIMARY KEY AUTO_INCREMENT,
    servidor_id INT NOT NULL,
    nivel ENUM('INFO', 'WARN', 'ERROR', 'SECURITY', 'AUDIT') NOT NULL DEFAULT 'INFO',
    origen VARCHAR(100) NOT NULL,
    evento VARCHAR(150) NOT NULL,
    mensaje TEXT NOT NULL,
    registrado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_logs_servidor_id (servidor_id),
    INDEX idx_logs_nivel (nivel),
    INDEX idx_logs_fecha (registrado_en),
    CONSTRAINT fk_logs_servidores FOREIGN KEY (servidor_id)
        REFERENCES servidores (id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS backups (
    id INT PRIMARY KEY AUTO_INCREMENT,
    servidor_id INT NOT NULL,
    tipo_backup ENUM('full', 'diferencial', 'incremental', 'snapshot') NOT NULL,
    estado ENUM('completado', 'fallido', 'en_proceso') NOT NULL DEFAULT 'completado',
    ejecutado_por VARCHAR(100) NOT NULL,
    tamanio_gb DECIMAL(10,2) NOT NULL DEFAULT 0.00 CHECK (tamanio_gb >= 0),
    retencion_dias INT UNSIGNED NOT NULL DEFAULT 30 CHECK (retencion_dias <= 365),
    fecha_backup TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_backups_servidor_id (servidor_id),
    INDEX idx_backups_estado (estado),
    INDEX idx_backups_fecha (fecha_backup),
    CONSTRAINT fk_backups_servidores FOREIGN KEY (servidor_id)
        REFERENCES servidores (id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS contenedores_docker (
    id INT PRIMARY KEY AUTO_INCREMENT,
    servidor_id INT NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    imagen VARCHAR(100) NOT NULL,
    version VARCHAR(50) NOT NULL,
    puerto_expuesto VARCHAR(50),
    estado ENUM('running', 'stopped', 'paused', 'failed') NOT NULL DEFAULT 'running',
    reinicios INT UNSIGNED NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_contenedores_nombre_servidor (servidor_id, nombre),
    INDEX idx_contenedores_estado (estado),
    CONSTRAINT fk_contenedores_servidores FOREIGN KEY (servidor_id)
        REFERENCES servidores (id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS monitoreo (
    id INT PRIMARY KEY AUTO_INCREMENT,
    servidor_id INT NOT NULL,
    servicio VARCHAR(100) NOT NULL,
    tipo_alerta ENUM('CPU', 'MEMORIA', 'DISCO', 'RED', 'SERVICIO') NOT NULL,
    valor DECIMAL(10,2) NOT NULL CHECK (valor >= 0),
    unidad VARCHAR(20) NOT NULL DEFAULT '%',
    nivel_severidad ENUM('verde', 'amarillo', 'rojo', 'critico') NOT NULL DEFAULT 'verde',
    registrado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_monitoreo_servidor_id (servidor_id),
    INDEX idx_monitoreo_tipo_alerta (tipo_alerta),
    INDEX idx_monitoreo_nivel_severidad (nivel_severidad),
    CONSTRAINT fk_monitoreo_servidores FOREIGN KEY (servidor_id)
        REFERENCES servidores (id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS accesos_ssh (
    id INT PRIMARY KEY AUTO_INCREMENT,
    empleado_id INT NULL,
    servidor_id INT NOT NULL,
    usuario VARCHAR(100) NOT NULL,
    direccion_ip VARCHAR(45) NOT NULL,
    exitoso BOOLEAN NOT NULL DEFAULT FALSE,
    intento_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    comentario VARCHAR(255),
    INDEX idx_accesos_ssh_servidor_id (servidor_id),
    INDEX idx_accesos_ssh_empleado_id (empleado_id),
    INDEX idx_accesos_ssh_exitoso (exitoso),
    CONSTRAINT fk_accesos_ssh_servidores FOREIGN KEY (servidor_id)
        REFERENCES servidores (id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_accesos_ssh_empleados FOREIGN KEY (empleado_id)
        REFERENCES empleados (id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Datos de ejemplo coherentes con la sede regional TI de Grupo Nutresa.
INSERT INTO departamentos (id, nombre, sede, responsable, presupuesto)
VALUES
(1, 'Tecnología e Infraestructura', 'Sede Regional', 'adminnutresa', 850000000.00),
(2, 'Recursos Humanos', 'Sede Regional', 'Carlos Mejía', 420000000.00),
(3, 'Logística y Distribución', 'Sede Regional', 'Ana Restrepo', 960000000.00),
(4, 'Ventas y Mercadeo', 'Sede Regional', 'Luis Gómez', 1200000000.00),
(5, 'Seguridad TI', 'Sede Regional', 'María Páez', 540000000.00);

INSERT INTO empleados (id, nombre, cargo, departamento, departamento_id, email, telefono, fecha_ingreso, salario, activo)
VALUES
(1, 'Carlos Andrés Mejía', 'Gerente de RRHH', 'Recursos Humanos', 2, 'c.mejia@nutresa.com', '3001234567', '2019-03-15', 8500000.00, TRUE),
(2, 'Ana María Restrepo', 'Coordinadora Logística', 'Logística y Distribución', 3, 'a.restrepo@nutresa.com', '3109876543', '2020-07-01', 6200000.00, TRUE),
(3, 'Luis Fernando Gómez', 'Director Comercial', 'Ventas y Mercadeo', 4, 'l.gomez@nutresa.com', '3205551234', '2018-01-10', 9800000.00, TRUE),
(4, 'María Paula Torres', 'Analista TI', 'Tecnología e Infraestructura', 1, 'm.torres@nutresa.com', '3154449876', '2021-05-20', 5400000.00, TRUE),
(5, 'Jorge Iván Salcedo', 'Técnico de Redes', 'Tecnología e Infraestructura', 1, 'j.salcedo@nutresa.com', '3006667788', '2022-02-14', 4800000.00, TRUE),
(6, 'Daniela Ríos', 'Especialista en Seguridad TI', 'Seguridad TI', 5, 'd.rios@nutresa.com', '3115554466', '2023-01-18', 6200000.00, TRUE),
(7, 'Ricardo Montes', 'Administrador de Bases de Datos', 'Tecnología e Infraestructura', 1, 'r.montes@nutresa.com', '3122227788', '2017-09-04', 7600000.00, TRUE);

INSERT INTO categorias_productos (id, nombre, unidad_negocio)
VALUES
(1, 'Chocolates', 'Chocolates'),
(2, 'Cafés', 'Cafés'),
(3, 'Galletas', 'Galletas'),
(4, 'Helados', 'Helados'),
(5, 'Cárnicos', 'Cárnicos'),
(6, 'Bebidas', 'Bebidas');

INSERT INTO productos (id, nombre, categoria, categoria_id, precio, stock, unidad_negocio, activo)
VALUES
(1, 'Chocolate Santander 70%', 'Chocolates', 1, 12500.00, 3200, 'Chocolates', TRUE),
(2, 'Café Colcafé Liofilizado', 'Cafés', 2, 18900.00, 1800, 'Cafés', TRUE),
(3, 'Galletas Festival Limón', 'Galletas', 3, 4200.00, 5600, 'Galletas', TRUE),
(4, 'Helado Mimo''s Vainilla', 'Helados', 4, 8700.00, 920, 'Helados', TRUE),
(5, 'Salchicha Zenú Premium', 'Cárnicos', 5, 15300.00, 2100, 'Cárnicos', TRUE),
(6, 'Bebida Zenú Energética', 'Bebidas', 6, 6500.00, 1200, 'Bebidas', TRUE);

INSERT INTO servidores (id, hostname, ip, sistema_operativo, rol, departamento_id, estado, ubicacion, capacidad_memoria_gb, capacidad_cpu)
VALUES
(1, 'nutresa-server', '10.0.2.15', 'Ubuntu Server 24.04 LTS', 'Servidor principal', 1, 'activo', 'Sede Regional', 64, 16),
(2, 'nutresa-web', '172.18.0.2', 'Docker - Nginx', 'Portal web corporativo', 1, 'activo', 'Sede Regional', 16, 4),
(3, 'nutresa-db', '172.18.0.3', 'Docker - MySQL 8.0', 'Base de datos', 1, 'activo', 'Sede Regional', 32, 8),
(4, 'nutresa-samba', '172.18.0.4', 'Docker - Samba', 'Archivos compartidos', 1, 'activo', 'Sede Regional', 16, 4),
(5, 'nutresa-grafana', '172.18.0.5', 'Docker - Grafana', 'Monitoreo', 1, 'activo', 'Sede Regional', 16, 4),
(6, 'nutresa-vpn', '172.18.0.6', 'Ubuntu Server 24.04 LTS', 'VPN corporativa', 5, 'activo', 'Sede Regional', 16, 4);

INSERT INTO logs_sistema (servidor_id, nivel, origen, evento, mensaje)
VALUES
(1, 'INFO', 'sistema', 'Inicio normal', 'El servidor principal booting con éxito y servicios de infraestructura cargados.'),
(3, 'WARN', 'mysql', 'Uso alto de CPU', 'El servidor de bases de datos alcanzó el 82% de CPU durante ventana batch.'),
(5, 'INFO', 'grafana', 'Monitoreo activo', 'Grafana está recolectando métricas para 12 hosts.'),
(6, 'SECURITY', 'vpn', 'Conexión remota', 'Acceso SSH autorizado desde 192.168.10.24 para mantenimiento remoto.');

INSERT INTO backups (servidor_id, tipo_backup, estado, ejecutado_por, tamanio_gb, retencion_dias)
VALUES
(1, 'full', 'completado', 'backup_operator', 350.75, 90),
(3, 'incremental', 'completado', 'backup_operator', 45.20, 30),
(6, 'snapshot', 'completado', 'seguridad', 12.40, 60);

INSERT INTO contenedores_docker (servidor_id, nombre, imagen, version, puerto_expuesto, estado, reinicios)
VALUES
(2, 'portal_web', 'nginx/nginx', '1.26.1', '80:80', 'running', 1),
(3, 'mysql_db', 'mysql/mysql-server', '8.0.34', '3306:3306', 'running', 0),
(4, 'samba_share', 'dperson/samba', '2.0.0', '445:445', 'running', 0),
(5, 'grafana_agent', 'grafana/agent', '0.30.0', '3000:3000', 'running', 0);

INSERT INTO monitoreo (servidor_id, servicio, tipo_alerta, valor, unidad, nivel_severidad)
VALUES
(1, 'Infraestructura', 'CPU', 62.5, '%', 'amarillo'),
(3, 'Base de datos', 'MEMORIA', 72.3, '%', 'amarillo'),
(5, 'Monitoreo', 'DISCO', 45.2, '%', 'verde'),
(6, 'VPN', 'RED', 12.1, '%', 'verde');

INSERT INTO accesos_ssh (empleado_id, servidor_id, usuario, direccion_ip, exitoso, comentario)
VALUES
(5, 1, 'j.salcedo', '192.168.10.120', TRUE, 'Mantenimiento preventivo programado.'),
(4, 3, 'm.torres', '192.168.10.121', TRUE, 'Verificación de configuración MySQL.'),
(6, 6, 'd.rios', '192.168.10.122', TRUE, 'Prueba de acceso seguro VPN.'),
(NULL, 2, 'ci_admin', '10.0.0.5', FALSE, 'Intento SSH no autorizado bloqueado.');

-- Consultas destacadas para sustentación académica.
-- 1) Inventario de servidores TI por estado y departamento.
SELECT s.hostname, s.ip, s.sistema_operativo, s.rol, d.nombre AS departamento, s.estado
FROM servidores s
LEFT JOIN departamentos d ON s.departamento_id = d.id
ORDER BY d.nombre, s.hostname;

-- 2) Productos por categoría y unidad de negocio.
SELECT p.nombre, p.categoria, c.unidad_negocio, p.precio, p.stock
FROM productos p
LEFT JOIN categorias_productos c ON p.categoria_id = c.id
WHERE p.activo = TRUE
ORDER BY c.unidad_negocio, p.nombre;

-- 3) Últimos eventos de monitoreo crítico o advertencias.
SELECT m.registrado_en, s.hostname, m.servicio, m.tipo_alerta, m.valor, m.nivel_severidad
FROM monitoreo m
JOIN servidores s ON m.servidor_id = s.id
WHERE m.nivel_severidad IN ('rojo', 'critico')
ORDER BY m.registrado_en DESC;

-- 4) Backups recientes de infraestructura TI.
SELECT b.fecha_backup, s.hostname, b.tipo_backup, b.estado, b.tamanio_gb, b.ejecutado_por
FROM backups b
JOIN servidores s ON b.servidor_id = s.id
ORDER BY b.fecha_backup DESC;

-- 5) Accesos SSH de auditoría con éxito y fallos.
SELECT a.intento_en, e.nombre AS empleado, s.hostname, a.usuario, a.direccion_ip, a.exitoso, a.comentario
FROM accesos_ssh a
LEFT JOIN empleados e ON a.empleado_id = e.id
JOIN servidores s ON a.servidor_id = s.id
ORDER BY a.intento_en DESC;
