USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.semanal_configuracion_delito', N'U') IS NULL
       OR OBJECT_ID(N'dbo.semanal_carga_delito_configurado', N'U') IS NULL
    BEGIN
        THROW 52100, 'No existen las tablas de configuración semanal que deben migrarse.', 1;
    END;

    DECLARE @ConfiguracionPorDelito BIT = CASE WHEN COL_LENGTH(N'dbo.semanal_configuracion_delito', N'id_delito') IS NOT NULL THEN 1 ELSE 0 END;
    DECLARE @ConfiguracionPorModalidad BIT = CASE WHEN COL_LENGTH(N'dbo.semanal_configuracion_delito', N'id_modalidad_delito') IS NOT NULL THEN 1 ELSE 0 END;
    DECLARE @CargaPorDelito BIT = CASE WHEN COL_LENGTH(N'dbo.semanal_carga_delito_configurado', N'id_delito') IS NOT NULL THEN 1 ELSE 0 END;
    DECLARE @CargaPorModalidad BIT = CASE WHEN COL_LENGTH(N'dbo.semanal_carga_delito_configurado', N'id_modalidad_delito') IS NOT NULL THEN 1 ELSE 0 END;

    IF @ConfiguracionPorModalidad = 1 AND @CargaPorModalidad = 1 AND @ConfiguracionPorDelito = 0 AND @CargaPorDelito = 0
    BEGIN
        COMMIT TRANSACTION;
        PRINT 'La configuración semanal ya trabaja por modalidad. No se realizaron cambios.';
        RETURN;
    END;

    IF @ConfiguracionPorDelito = 0 OR @CargaPorDelito = 0 OR @ConfiguracionPorModalidad = 1 OR @CargaPorModalidad = 1
    BEGIN
        THROW 52101, 'La estructura semanal está en un estado mixto y no es seguro migrarla automáticamente.', 1;
    END;

    IF OBJECT_ID(N'dbo.semanal_configuracion_delito_modalidad_nueva', N'U') IS NOT NULL
       OR OBJECT_ID(N'dbo.semanal_carga_delito_configurado_modalidad_nueva', N'U') IS NOT NULL
    BEGIN
        THROW 52102, 'Existen tablas temporales de una migración anterior. Revise su estado antes de continuar.', 1;
    END;

    CREATE TABLE dbo.semanal_configuracion_delito_modalidad_nueva
    (
        id_semanal_configuracion_delito INT IDENTITY(1,1) NOT NULL,
        id_modalidad_delito INT NOT NULL,
        es_obligatorio BIT NOT NULL CONSTRAINT DF_scd_modalidad_nueva_obligatorio DEFAULT (0),
        conservar_entre_periodos BIT NOT NULL CONSTRAINT DF_scd_modalidad_nueva_conservar DEFAULT (0),
        orden SMALLINT NOT NULL CONSTRAINT DF_scd_modalidad_nueva_orden DEFAULT (0),
        fecha_alta DATETIME2(0) NOT NULL CONSTRAINT DF_scd_modalidad_nueva_fecha_alta DEFAULT (SYSDATETIME()),
        fecha_modificacion DATETIME2(0) NOT NULL CONSTRAINT DF_scd_modalidad_nueva_fecha_modificacion DEFAULT (SYSDATETIME()),
        id_usuario_modificacion INT NULL,
        activo BIT NOT NULL CONSTRAINT DF_scd_modalidad_nueva_activo DEFAULT (1),
        CONSTRAINT PK_scd_modalidad_nueva PRIMARY KEY (id_semanal_configuracion_delito),
        CONSTRAINT UQ_scd_modalidad_nueva UNIQUE (id_modalidad_delito),
        CONSTRAINT FK_scd_modalidad_nueva_modalidad FOREIGN KEY (id_modalidad_delito) REFERENCES dbo.catalogo_modalidad_delito(id_modalidad_delito),
        CONSTRAINT FK_scd_modalidad_nueva_usuario FOREIGN KEY (id_usuario_modificacion) REFERENCES dbo.usuario(id_usuario),
        CONSTRAINT CK_scd_modalidad_nueva_obligatorio CHECK (es_obligatorio = 0 OR activo = 1)
    );

    INSERT INTO dbo.semanal_configuracion_delito_modalidad_nueva
    (
        id_modalidad_delito,
        es_obligatorio,
        conservar_entre_periodos,
        orden,
        fecha_alta,
        fecha_modificacion,
        id_usuario_modificacion,
        activo
    )
    SELECT
        md.id_modalidad_delito,
        configuracion.es_obligatorio,
        configuracion.conservar_entre_periodos,
        CONVERT(SMALLINT, ROW_NUMBER() OVER (ORDER BY CASE WHEN configuracion.activo = 1 THEN 0 ELSE 1 END, configuracion.orden, md.clave4)),
        configuracion.fecha_alta,
        configuracion.fecha_modificacion,
        configuracion.id_usuario_modificacion,
        configuracion.activo
    FROM dbo.semanal_configuracion_delito configuracion
    INNER JOIN dbo.catalogo_subtipo_delito sd ON sd.id_delito = configuracion.id_delito
    INNER JOIN dbo.catalogo_modalidad_delito md ON md.id_subtipo_delito = sd.id_subtipo_delito;

    DECLARE @ModalidadesExtorsion TABLE (id_modalidad_delito INT NOT NULL PRIMARY KEY, orden SMALLINT NOT NULL);

    INSERT INTO @ModalidadesExtorsion (id_modalidad_delito, orden)
    SELECT md.id_modalidad_delito, CONVERT(SMALLINT, ROW_NUMBER() OVER (ORDER BY md.clave4))
    FROM dbo.catalogo_modalidad_delito md
    INNER JOIN dbo.catalogo_subtipo_delito sd ON sd.id_subtipo_delito = md.id_subtipo_delito AND sd.activo = 1
    INNER JOIN dbo.catalogo_delito cd ON cd.id_delito = sd.id_delito AND cd.activo = 1
    WHERE cd.clave2 = N'4.04'
      AND md.activo = 1;

    IF NOT EXISTS (SELECT 1 FROM @ModalidadesExtorsion)
    BEGIN
        THROW 52103, 'No se encontraron modalidades activas de Extorsión para la clave 4.04.', 1;
    END;

    UPDATE configuracion
    SET configuracion.es_obligatorio = 1,
        configuracion.conservar_entre_periodos = 1,
        configuracion.orden = extorsion.orden,
        configuracion.fecha_modificacion = SYSDATETIME(),
        configuracion.activo = 1
    FROM dbo.semanal_configuracion_delito_modalidad_nueva configuracion
    INNER JOIN @ModalidadesExtorsion extorsion ON extorsion.id_modalidad_delito = configuracion.id_modalidad_delito;

    INSERT INTO dbo.semanal_configuracion_delito_modalidad_nueva (id_modalidad_delito, es_obligatorio, conservar_entre_periodos, orden, activo)
    SELECT extorsion.id_modalidad_delito, 1, 1, extorsion.orden, 1
    FROM @ModalidadesExtorsion extorsion
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM dbo.semanal_configuracion_delito_modalidad_nueva configuracion
        WHERE configuracion.id_modalidad_delito = extorsion.id_modalidad_delito
    );

    CREATE TABLE dbo.semanal_carga_delito_configurado_modalidad_nueva
    (
        id_semanal_carga_delito_configurado BIGINT IDENTITY(1,1) NOT NULL,
        id_semanal_carga BIGINT NOT NULL,
        id_modalidad_delito INT NOT NULL,
        es_obligatorio BIT NOT NULL,
        conservar_entre_periodos BIT NOT NULL,
        orden SMALLINT NOT NULL,
        fecha_registro DATETIME2(0) NOT NULL CONSTRAINT DF_sccdm_nueva_fecha DEFAULT (SYSDATETIME()),
        CONSTRAINT PK_sccdm_nueva PRIMARY KEY (id_semanal_carga_delito_configurado),
        CONSTRAINT UQ_sccdm_nueva UNIQUE (id_semanal_carga, id_modalidad_delito),
        CONSTRAINT FK_sccdm_nueva_carga FOREIGN KEY (id_semanal_carga) REFERENCES dbo.semanal_carga(id_semanal_carga),
        CONSTRAINT FK_sccdm_nueva_modalidad FOREIGN KEY (id_modalidad_delito) REFERENCES dbo.catalogo_modalidad_delito(id_modalidad_delito)
    );

    INSERT INTO dbo.semanal_carga_delito_configurado_modalidad_nueva
    (
        id_semanal_carga,
        id_modalidad_delito,
        es_obligatorio,
        conservar_entre_periodos,
        orden,
        fecha_registro
    )
    SELECT
         configuracion.id_semanal_carga,
        md.id_modalidad_delito,
        configuracion.es_obligatorio,
        configuracion.conservar_entre_periodos,
        CONVERT(SMALLINT, ROW_NUMBER() OVER (PARTITION BY configuracion.id_semanal_carga ORDER BY configuracion.orden, md.clave4)),
        configuracion.fecha_registro
    FROM dbo.semanal_carga_delito_configurado configuracion
    INNER JOIN dbo.catalogo_subtipo_delito sd ON sd.id_delito = configuracion.id_delito
    INNER JOIN dbo.catalogo_modalidad_delito md ON md.id_subtipo_delito = sd.id_subtipo_delito;

    IF OBJECT_ID(N'dbo.semanal_delito', N'U') IS NOT NULL
       AND EXISTS
       (
           SELECT 1
           FROM dbo.semanal_delito delito
           LEFT JOIN dbo.semanal_carga_delito_configurado_modalidad_nueva configuracion
             ON configuracion.id_semanal_carga = delito.id_semanal_carga
            AND configuracion.id_modalidad_delito = delito.id_modalidad_delito
           WHERE configuracion.id_semanal_carga IS NULL
       )
    BEGIN
        THROW 52104, 'Existen delitos semanales cuya modalidad no estaba incluida en la configuración de su carga.', 1;
    END;

    IF OBJECT_ID(N'dbo.semanal_delito_historico', N'U') IS NOT NULL
       AND EXISTS
       (
           SELECT 1
           FROM dbo.semanal_delito_historico delito
           LEFT JOIN dbo.semanal_carga_delito_configurado_modalidad_nueva configuracion
             ON configuracion.id_semanal_carga = delito.id_semanal_carga
            AND configuracion.id_modalidad_delito = delito.id_modalidad_delito
           WHERE configuracion.id_semanal_carga IS NULL
       )
    BEGIN
        THROW 52105, 'Existen delitos históricos semanales cuya modalidad no estaba incluida en la configuración de su carga.', 1;
    END;

    IF OBJECT_ID(N'dbo.FK_semanal_delito_configurado', N'F') IS NOT NULL ALTER TABLE dbo.semanal_delito DROP CONSTRAINT FK_semanal_delito_configurado;
    IF OBJECT_ID(N'dbo.FK_semanal_delito_historico_configurado', N'F') IS NOT NULL ALTER TABLE dbo.semanal_delito_historico DROP CONSTRAINT FK_semanal_delito_historico_configurado;

    DROP TABLE dbo.semanal_carga_delito_configurado;
    DROP TABLE dbo.semanal_configuracion_delito;

    EXEC sys.sp_rename N'dbo.semanal_configuracion_delito_modalidad_nueva', N'semanal_configuracion_delito';
    EXEC sys.sp_rename N'dbo.semanal_carga_delito_configurado_modalidad_nueva', N'semanal_carga_delito_configurado';

    IF OBJECT_ID(N'dbo.semanal_delito', N'U') IS NOT NULL
    BEGIN
        ALTER TABLE dbo.semanal_delito WITH CHECK ADD CONSTRAINT FK_semanal_delito_configurado FOREIGN KEY (id_semanal_carga, id_modalidad_delito) REFERENCES dbo.semanal_carga_delito_configurado(id_semanal_carga, id_modalidad_delito);
    END;

    IF OBJECT_ID(N'dbo.semanal_delito_historico', N'U') IS NOT NULL
    BEGIN
        ALTER TABLE dbo.semanal_delito_historico WITH CHECK ADD CONSTRAINT FK_semanal_delito_historico_configurado FOREIGN KEY (id_semanal_carga, id_modalidad_delito) REFERENCES dbo.semanal_carga_delito_configurado(id_semanal_carga, id_modalidad_delito);
    END;

    COMMIT TRANSACTION;

    SELECT
        COL_LENGTH(N'dbo.semanal_configuracion_delito', N'id_modalidad_delito') AS configuracion_por_modalidad,
        COL_LENGTH(N'dbo.semanal_carga_delito_configurado', N'id_modalidad_delito') AS carga_por_modalidad,
        (SELECT COUNT(*) FROM dbo.semanal_configuracion_delito WHERE activo = 1) AS modalidades_seleccionadas,
        (SELECT COUNT(*) FROM dbo.semanal_configuracion_delito WHERE activo = 1 AND es_obligatorio = 1) AS modalidades_obligatorias;

    PRINT 'Configuración semanal migrada correctamente al nivel de modalidad.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO