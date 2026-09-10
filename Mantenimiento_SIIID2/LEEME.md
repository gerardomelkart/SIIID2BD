# Mantenimiento general de SIIID2

Repo: `gerardomelkart/SIIID2BD`.
Base revisada: `origin/main`, commit `8244c4eebfac1903f2999a859d7fc848aea3fd72`.

## Archivos nuevos y ubicación exacta

| Archivo del paquete | Ruta dentro del repo |
| --- | --- |
| `modulo_federal/mantenimientoFederal.sql` | `SIIID2BD/modulo federal/mantenimientoFederal.sql` |
| `utils/procedimientoMantenimientoGeneral.sql` | `SIIID2BD/utils/procedimientoMantenimientoGeneral.sql` |
| `utils/ejecutarMantenimientoGeneral.sh` | `SIIID2BD/utils/ejecutarMantenimientoGeneral.sh` |

Los scripts de mensual y semanal ya existentes no se reemplazan. El general llama sus procedimientos con parámetros explícitos.

## 1. Instalar primero en desarrollo

En SSMS, conectado a desarrollo, ejecutar completos en este orden:

1. `mantenimientoFederal.sql`.
2. `procedimientoMantenimientoGeneral.sql`.

Se usa modo normal de SSMS; no requiere SQLCMD ni rutas de archivos. Estos dos scripts instalan objetos, no ejecutan la limpieza. El segundo crea `dbo.mantenimiento_ejecucion` y el procedimiento general. Reejecutarlos conserva la bitácora.

Los procedimientos existentes `dbo.usp_mantenimiento_mensual` y `dbo.usp_mantenimiento_semanal` deben estar instalados. Si faltan, sus archivos actuales en el repo son `utils/procedimientoMantenimientoMensual.sql` y `semanal/mantenimientoSemanal.sql`.

En una ventana sin transacción abierta, ejecutar primero:

```sql
USE siiid2;
GO
SET IMPLICIT_TRANSACTIONS OFF;
EXEC dbo.usp_mantenimiento_general
    @EjecutarMantenimiento = 0,
    @ActualizarEstadisticas = 0;
```

La simulación ejecuta las eliminaciones y las revierte. Puede tomar bloqueos; no es una consulta exclusivamente de lectura. Conserva el registro de la ejecución en `dbo.mantenimiento_ejecucion`.

Al terminar correctamente la simulación, ejecutar la limpieza real en desarrollo:

```sql
USE siiid2;
GO
SET IMPLICIT_TRANSACTIONS OFF;
EXEC dbo.usp_mantenimiento_general
    @EjecutarMantenimiento = 1,
    @ActualizarEstadisticas = 1;
```

Para consultar el resultado:

```sql
SELECT TOP (30)
    id_ejecucion, modulo, fecha_inicio, fecha_fin,
    ejecutar_mantenimiento, actualizar_estadisticas,
    estado, error_numero, mensaje
FROM dbo.mantenimiento_ejecucion
ORDER BY id_mantenimiento_ejecucion DESC;
```

El general ejecuta mensual, semanal y Federal en ese orden. Cada uno confirma su propia transacción. Si falla un módulo, se registra ERROR y los siguientes quedan OMITIDO. Los anteriores no se revierten. Un error posterior al COMMIT, por ejemplo en estadísticas, tampoco revierte una limpieza ya confirmada. Una terminación abrupta de la conexión puede dejar EN_PROCESO; revisar antes de reintentar.

Los conteos de limpieza de cada módulo aparecen en los resultados de SSMS y en el log del ejecutor Linux. La tabla de bitácora guarda estado, fechas y error, no duplica esos conteos.

## 2. Alcance Federal

- Borra exclusivamente `federal_carga_tmp_victima`, `federal_carga_tmp_delito` y `federal_carga_tmp_carpeta` cuando su carga no está protegida.
- Conserva VALIDADO_PENDIENTE, VALIDADO_PENDIENTE_ACTUALIZACION y PENDIENTE_APROBACION, igual que mensual, incluso si el registro está inactivo.
- Conserva el último RECHAZADO_ADMIN activo por año, mes y tipo de carga, mientras no exista una carga posterior activa con un estado válido que lo sustituya. Un intento posterior rechazado por validación o expirado no lo sustituye.
- El período Federal es nacional, compartido entre usuarios. No se separa por entidad ni por usuario al resolver ese último rechazo.
- No elimina registros definitivos, históricos, cargas, usuarios, advertencias, bitácoras, catálogos ni la trazabilidad de la migración FGR. No modifica los archivos originales del disco.
- Actualiza estadísticas de las mismas diez tablas equivalentes al mensual, con FULLSCAN.
- Durante la limpieza Federal bloquea temporalmente la tabla de cargas para conservar una selección consistente. Ejecutar el mantenimiento fuera de la ventana de carga. Mensual y semanal mantienen su implementación vigente.
- El bloqueo del general evita dos ejecuciones simultáneas del general. No bloquea llamadas directas a los procedimientos individuales: retirar la programación anterior al activar la nueva.

## 3. Pasar a producción

Después de la prueba en desarrollo, instalar los mismos dos SQL en producción, primero Federal y después general. Ejecutar allí la simulación y la limpieza real como se indica arriba, fuera de la ventana de carga.

La instalación no programa automáticamente el mantenimiento. El apartado siguiente deja una sola programación mediante cron para el servidor Linux al que te conectas con `ssh siiid`.

## 4. Preparar el ejecutor Linux

En PowerShell, ajustando sólo la ruta de extracción local si elegiste otra:

```powershell
scp "D:\CNI\Mantenimiento_SIIID2\utils\ejecutarMantenimientoGeneral.sh" "siiid:/home/opc/ejecutarMantenimientoGeneral.sh"
ssh siiid
```

Dentro de Linux, como `opc`:

```bash
install -d -m 700 /home/opc/mantenimiento_siiid2 /home/opc/.config/siiid2
sed -i 's/\r$//' /home/opc/ejecutarMantenimientoGeneral.sh
install -m 700 /home/opc/ejecutarMantenimientoGeneral.sh /home/opc/mantenimiento_siiid2/ejecutarMantenimientoGeneral.sh
```

Crear la configuración sólo si aún no existe. Ejecutar este bloque completo en Linux. Solicita el login y contraseña de SQL Server; no son los de SSH. La contraseña no se imprime ni se escribe en el historial de comandos.

```bash
(
    set -e
    umask 077
    CONFIG_MANTENIMIENTO=/home/opc/.config/siiid2/mantenimiento.env
    if [ -e "$CONFIG_MANTENIMIENTO" ]; then
        echo "Ya existe $CONFIG_MANTENIMIENTO; se conserva."
        exit 0
    fi
    read -r -p 'Servidor SQL [127.0.0.1,1433]: ' SERVIDOR_MANTENIMIENTO
    SERVIDOR_MANTENIMIENTO=${SERVIDOR_MANTENIMIENTO:-127.0.0.1,1433}
    read -r -p 'Usuario SQL Server: ' USUARIO_MANTENIMIENTO
    read -r -s -p 'Contraseña SQL Server: ' PASSWORD_MANTENIMIENTO
    echo
    [ -n "$USUARIO_MANTENIMIENTO" ] && [ -n "$PASSWORD_MANTENIMIENTO" ] || exit 1
    read -r -p '¿Confiar en el certificado autofirmado conocido del servidor? [s/N]: ' CERTIFICADO_MANTENIMIENTO
    CONFIAR_MANTENIMIENTO=0
    if [[ "$CERTIFICADO_MANTENIMIENTO" == s || "$CERTIFICADO_MANTENIMIENTO" == S ]]; then
        CONFIAR_MANTENIMIENTO=1
    fi
    set -o noclobber
    {
        printf 'SQLCMD_SERVER=%q\n' "$SERVIDOR_MANTENIMIENTO"
        printf 'SQLCMD_USER=%q\n' "$USUARIO_MANTENIMIENTO"
        printf 'SQLCMDPASSWORD=%q\n' "$PASSWORD_MANTENIMIENTO"
        printf 'SQLCMD_TRUST_SERVER_CERTIFICATE=%s\n' "$CONFIAR_MANTENIMIENTO"
    } > "$CONFIG_MANTENIMIENTO"
)
```

La cuenta SQL debe tener permiso para ejecutar los procedimientos, borrar en las tablas temporales y actualizar estadísticas (por ejemplo, la cuenta administrativa que ya usas en SSMS). El script busca `sqlcmd` en las rutas habituales. Si no está instalado, lo indica sin ejecutar mantenimiento.

Probar desde Linux:

```bash
/home/opc/mantenimiento_siiid2/ejecutarMantenimientoGeneral.sh simular
```

Cuando termine correctamente, la ejecución real es:

```bash
/home/opc/mantenimiento_siiid2/ejecutarMantenimientoGeneral.sh aplicar
```

Cada llamada genera un log en `/home/opc/mantenimiento_siiid2/logs`. Los fallos de SQL producen un código de salida distinto de cero. No se incluyen contraseñas en los argumentos de sqlcmd ni en el log.

## 5. Sustituir la programación anterior

Antes de activarla, revisar las tareas existentes para evitar ejecutar también los mantenimientos individuales. En Linux:

```bash
date
crontab -l
systemctl is-active crond
```

En SSMS de producción, revisar edición y jobs existentes:

```sql
SELECT @@SERVERNAME AS servidor, SERVERPROPERTY('Edition') AS edicion;
SELECT name, enabled
FROM msdb.dbo.sysjobs
WHERE name IN
(
    N'SIIID2 - Mantenimiento mensual',
    N'SIIID2 - Mantenimiento semanal',
    N'SIIID2 - Mantenimiento general'
);
```

Si existen los dos jobs anteriores, deshabilitarlos justo al sustituirlos por la programación nueva. Este bloque sólo modifica esos dos jobs y se puede repetir:

```sql
USE msdb;
GO
IF EXISTS (SELECT 1 FROM dbo.sysjobs WHERE name = N'SIIID2 - Mantenimiento mensual')
    EXEC dbo.sp_update_job @job_name = N'SIIID2 - Mantenimiento mensual', @enabled = 0;
IF EXISTS (SELECT 1 FROM dbo.sysjobs WHERE name = N'SIIID2 - Mantenimiento semanal')
    EXEC dbo.sp_update_job @job_name = N'SIIID2 - Mantenimiento semanal', @enabled = 0;
```

En Express, SQL Server Agent no ejecuta jobs; se utiliza cron. Si no existen los jobs anteriores, no hay nada que deshabilitar. Si hay tareas anteriores en cron o systemd para estos dos mantenimientos, retirarlas antes de activar esta única entrada.

En Linux, como `opc`, abrir:

```bash
crontab -e
```

Agregar una sola vez esta línea:

```cron
0 3 14 * * /home/opc/mantenimiento_siiid2/ejecutarMantenimientoGeneral.sh aplicar >> /home/opc/mantenimiento_siiid2/cron.log 2>&1
```

Se ejecutará el día 14 de cada mes a las 03:00, según la zona horaria del servidor: el horario inicial del job mensual vigente. Ahora los tres módulos se ejecutan en secuencia desde esa única entrada. Los logs se conservan para diagnóstico; este paquete no los purga automáticamente.

Para detener la programación, retirar esa línea con `crontab -e`; los procedimientos siguen disponibles para ejecución manual.

## Validación de la entrega

Se contrastaron objetos y columnas con la estructura Federal actual, las protecciones con el mantenimiento mensual y el alcance nacional con la API actual. Se verificaron escenarios de pendientes, rechazos sucesivos, tipos de carga y usuarios distintos, aislamiento de las tablas eliminadas y sintaxis/propagación de errores del ejecutor Bash.

No se ejecutaron estos procedimientos en una instancia SQL Server desde este entorno. La compilación y la prueba de ejecución corresponden al paso de desarrollo indicado arriba.
