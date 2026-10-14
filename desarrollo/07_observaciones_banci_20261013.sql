-- SIIID2 BANCI: homologar POB y DISC a los catálogos compartidos.
-- Ejecutar sobre la base SELECCIONADA en SSMS: Desarrollo, QA o Producción.
-- PREVIAMENTE: respaldar la base y detener cargas/actualizaciones BANCI.
-- No usa USE, no contiene @Aplicar y NO redefine procedimientos almacenados.
-- Conserva staging/históricos. Convierte el valor antiguo 0=No a 2=No
-- exclusivamente en dbo.banci_victima; conserva 1=Sí.
-- La API verifica además que las claves de los catálogos estén activas.
SET NOCOUNT ON;
SET XACT_ABORT ON;

IF @@TRANCOUNT <> 0
    THROW 52700, 'Ejecute este ajuste sin una transacción abierta.', 1;
IF DB_NAME() IN (N'master', N'model', N'msdb', N'tempdb')
    THROW 52701, 'Seleccione explícitamente la base SIIID2 correspondiente.', 1;
IF OBJECT_ID(N'dbo.banci_victima', N'U') IS NULL
    OR OBJECT_ID(N'dbo.banci_carga', N'U') IS NULL
    THROW 52702, 'La estructura BANCI requerida no existe.', 1;
IF OBJECT_ID(N'dbo.catalogo_pertenece_poblacion_indigena', N'U') IS NULL
    OR OBJECT_ID(N'dbo.catalogo_presenta_discapacidad', N'U') IS NULL
    THROW 52703, 'No existen los catálogos institucionales POB/DISC.', 1;
IF COL_LENGTH(N'dbo.banci_victima', N'pob') IS NULL
    OR COL_LENGTH(N'dbo.banci_victima', N'disc') IS NULL
    THROW 52704, 'Faltan columnas POB/DISC en BANCI.', 1;

-- Comprobar la equivalencia 0=No -> 2=No y que toda clave ya informada
-- (excepto el antiguo cero) exista y esté activa en el catálogo compartido.
IF NOT EXISTS (SELECT 1 FROM dbo.catalogo_pertenece_poblacion_indigena WHERE clave = 2 AND activo = 1)
    OR NOT EXISTS (SELECT 1 FROM dbo.catalogo_presenta_discapacidad WHERE clave = 2 AND activo = 1)
    THROW 52705, 'No existe la clave activa 2=No en ambos catálogos.', 1;
IF EXISTS
(
    SELECT 1 FROM dbo.banci_victima v
    WHERE (v.pob IS NOT NULL AND v.pob <> 0 AND NOT EXISTS
           (SELECT 1 FROM dbo.catalogo_pertenece_poblacion_indigena c WHERE c.clave = v.pob AND c.activo = 1))
       OR (v.disc IS NOT NULL AND v.disc <> 0 AND NOT EXISTS
           (SELECT 1 FROM dbo.catalogo_presenta_discapacidad c WHERE c.clave = v.disc AND c.activo = 1))
)
    THROW 52706, 'BANCI contiene claves POB/DISC ausentes o inactivas en los catálogos.', 1;

-- No cambiar datos mientras existen decisiones BANCI en curso.
IF EXISTS (SELECT 1 FROM dbo.banci_carga WHERE activo = 1
           AND estado IN (N'RECIBIDO', N'VALIDANDO', N'VALIDADO', N'VALIDADO_PENDIENTE', N'PROCESANDO'))
    THROW 52707, 'Existen cargas BANCI pendientes; resuélvalas antes del ajuste.', 1;
IF OBJECT_ID(N'dbo.banci_actualizacion_v2', N'U') IS NOT NULL
    AND EXISTS (SELECT 1 FROM dbo.banci_actualizacion_v2 WHERE estado = N'PENDIENTE')
    THROW 52708, 'Existen actualizaciones BANCI pendientes.', 1;

-- Nunca sustituir una relación existente que apunte a otro objeto.
IF EXISTS (SELECT 1 FROM sys.foreign_keys f
    WHERE f.name = N'FK_banci_victima_pob_catalogo'
      AND (f.parent_object_id <> OBJECT_ID(N'dbo.banci_victima')
           OR f.referenced_object_id <> OBJECT_ID(N'dbo.catalogo_pertenece_poblacion_indigena')))
   OR EXISTS (SELECT 1 FROM sys.foreign_keys f
    WHERE f.name = N'FK_banci_victima_disc_catalogo'
      AND (f.parent_object_id <> OBJECT_ID(N'dbo.banci_victima')
           OR f.referenced_object_id <> OBJECT_ID(N'dbo.catalogo_presenta_discapacidad')))
    THROW 52709, 'Existe una relación POB/DISC con el mismo nombre y otro destino.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    -- Quitar sólo las dos restricciones antiguas identificadas de BANCI.
    IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N'dbo.banci_victima')
               AND name = N'CK_banci_victima_pob')
        ALTER TABLE dbo.banci_victima DROP CONSTRAINT CK_banci_victima_pob;
    IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE parent_object_id = OBJECT_ID(N'dbo.banci_victima')
               AND name = N'CK_banci_victima_disc')
        ALTER TABLE dbo.banci_victima DROP CONSTRAINT CK_banci_victima_disc;

    UPDATE dbo.banci_victima SET pob = 2 WHERE pob = 0;
    UPDATE dbo.banci_victima SET disc = 2 WHERE disc = 0;

    -- FK por clave (UNIQUE en ambos catálogos). La nulabilidad se conserva.
    IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID(N'dbo.banci_victima')
                   AND name = N'FK_banci_victima_pob_catalogo')
        ALTER TABLE dbo.banci_victima WITH CHECK
            ADD CONSTRAINT FK_banci_victima_pob_catalogo
            FOREIGN KEY (pob) REFERENCES dbo.catalogo_pertenece_poblacion_indigena(clave);
    IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID(N'dbo.banci_victima')
                   AND name = N'FK_banci_victima_disc_catalogo')
        ALTER TABLE dbo.banci_victima WITH CHECK
            ADD CONSTRAINT FK_banci_victima_disc_catalogo
            FOREIGN KEY (disc) REFERENCES dbo.catalogo_presenta_discapacidad(clave);

    ALTER TABLE dbo.banci_victima WITH CHECK CHECK CONSTRAINT FK_banci_victima_pob_catalogo;
    ALTER TABLE dbo.banci_victima WITH CHECK CHECK CONSTRAINT FK_banci_victima_disc_catalogo;

    COMMIT TRANSACTION;
    SELECT @@SERVERNAME AS servidor, DB_NAME() AS base_actual,
           N'POB/DISC vinculados a los catálogos institucionales' AS resultado,
           (SELECT COUNT_BIG(*) FROM dbo.banci_victima WHERE pob = 0 OR disc = 0) AS ceros_pendientes;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
