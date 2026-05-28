README del servidor de archivos Samba - Grupo Nutresa

Descripción general
Este servidor de archivos Samba forma parte de la infraestructura TI de la sede regional de Grupo Nutresa. Su objetivo es centralizar el almacenamiento colaborativo de documentos corporativos, respaldos de procedimientos y archivos compartidos entre los departamentos de Tecnología e Infraestructura, RRHH, Logística, Ventas y Seguridad TI.

La implementación se ejecuta sobre Ubuntu Server 24.04 LTS en una máquina virtual con Docker, complemento del ecosistema que incluye Nginx, MySQL, Grafana y Samba.

Acceso desde Windows
Para acceder desde una estación de trabajo Windows, utilice la ruta UNC correspondiente al servidor Samba:

\\\nutresa-samba\compartidos

En Windows Explorer, escriba la ruta en la barra de dirección y autentíquese con su usuario de dominio corporativo. El acceso está configurado para permitir únicamente usuarios autorizados por el equipo de TI.

Acceso desde Linux
Desde sistemas Linux, el acceso puede realizarse con `smbclient` o montando el recurso como sistema de archivos:

```bash
smbclient //nutresa-samba/compartidos -U adminnutresa
```

O montando con CIFS:

```bash
sudo mount -t cifs //nutresa-samba/compartidos /mnt/compartidos -o username=adminnutresa,password=SuPasswordSegura,vers=3.0
```

Lista de carpetas compartidas y permisos
El servidor Samba expone las siguientes rutas compartidas internas:

- `compartidos`: carpeta principal de trabajo colaborativo. Permisos de lectura/escritura para usuarios autorizados de los departamentos.
- `rrhh`: documentos de Recursos Humanos con acceso restringido a personal de RRHH y Seguridad TI.
- `logistica`: información de inventario, órdenes y rutas de transporte para el área de Logística.
- `ventas`: archivos de propuestas comerciales, precios y material de apoyo para el equipo de Ventas.
- `seguridad`: registros de auditoría, políticas y análisis de seguridad accesibles solo por Seguridad TI.
- `backups`: carpeta de respaldo controlada para archivos críticos respaldados por el script `backup.sh`.

Permisos de carpetas
- `compartidos`: lectura/escritura para miembros de Tecnología, Logística, Ventas; lectura para Seguridad TI.
- `rrhh`: solo lectura/escritura para RRHH y Seguridad TI.
- `logistica`: lectura/escritura para Logística y Tecnología e Infraestructura.
- `ventas`: lectura/escritura para Ventas y Tecnología e Infraestructura.
- `seguridad`: lectura/escritura exclusiva para Seguridad TI y Administrador.
- `backups`: escritura controlada por scripts de backup y lectura para administradores de TI.

Política de almacenamiento
La política de almacenamiento de Samba establece cuotas y controles para mantener la disponibilidad y el rendimiento del servidor:

- Cada departamento tiene una cuota máxima de 200 GB en el recurso compartido principal.
- Los usuarios individuales no deben almacenar archivos personales ni multimedia no relacionados con el trabajo.
- Se permite la carga de documentos corporativos, plantillas, informes, bases de datos de trabajo y scripts aprobados.
- No se permiten archivos ejecutables no autorizados, aplicaciones portables ni material de origen desconocido.
- Los archivos temporales, respaldos personales y documentos obsoletos deben eliminarse periódicamente para liberar espacio.

Procedimiento para solicitar acceso
1. El usuario solicita acceso a través de ticket en el sistema de helpdesk con categoría "Acceso Samba".
2. El ticket debe incluir departamento, justificación del acceso y carpeta solicitada.
3. El nivel 1 de soporte TI (María Paula Torres o Jorge Iván Salcedo) revisa la solicitud.
4. Si el acceso es aprobado, el Administrador `adminnutresa` configura permisos en Samba y notifica al usuario.
5. El usuario recibe credenciales en su correo corporativo y la ruta UNC correspondiente.

Procedimiento para reportar archivos corruptos o perdidos
1. Reporte inmediato a soporte TI mediante ticket con prioridad alta si el archivo es crítico.
2. Incluya nombre de archivo, ruta compartida, departamento y descripción del problema.
3. El equipo de soporte revisa los logs de Samba y valida la integridad del archivo en el servidor.
4. Si el archivo pertenece a una copia de seguridad reciente, se restaura desde `/data/backups` o mediante la política de backup diario.
5. Se realiza seguimiento del incidente hasta la recuperación completa y se documenta en el registro de incidentes.

Contacto del administrador
- Administrador de Samba y plataforma: adminnutresa
- Correo: adminnutresa@nutresa.com.co
- Extensión interna: 1001
- Atención: Lunes a Viernes de 08:00 a 18:00

Mantenimiento y soporte
- El servidor Samba se revisa diariamente como parte del monitoreo automático.
- Las copias de seguridad se ejecutan cada noche y se retienen durante 7 días.
- El equipo de Seguridad TI supervisa los accesos y auditorías semanales.
- Las ventanas de mantenimiento programado se publican con 48 horas de anticipación.

Buenas prácticas de uso
- Organice los documentos por carpetas y mantenga nombres claros.
- No duplique grandes archivos en varias carpetas si no es necesario.
- Elimine versiones antiguas de documentos cuando se archiven.
- Verifique los permisos antes de compartir documentos sensibles.
- Use comentarios internos para describir el propósito de los archivos.

Información adicional
El servidor Samba es parte de la infraestructura de almacenamiento colaborativo de la sede regional. Opera junto a los servicios de Docker, Nginx, MySQL y Grafana, formando un entorno con alta disponibilidad basado en RAID 1 y LVM. La seguridad y el cumplimiento son prioridades, por lo que cualquier cambio en el acceso debe ser validado por Seguridad TI.

Este README sirve como guía de uso para los empleados autorizados y los equipos de soporte de Grupo Nutresa en la sede regional.
