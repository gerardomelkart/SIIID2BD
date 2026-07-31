USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.semanal_carga', N'U') IS NULL
    BEGIN
        THROW 52200, 'No existe dbo.semanal_carga. Ejecute primero la estructura del módulo semanal.', 1;
    END;

    IF OBJECT_ID(N'dbo.catalogo_entidad_federativa', N'U') IS NULL
    BEGIN
        THROW 52201, 'No existe dbo.catalogo_entidad_federativa.', 1;
    END;

    IF OBJECT_ID(N'dbo.semanal_carga_bloque', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.semanal_carga_bloque
        (
            id_semanal_carga_bloque BIGINT IDENTITY(1,1) NOT NULL,
            id_semanal_carga BIGINT NOT NULL,
            id_entidad_federativa TINYINT NOT NULL,
            anio_semana SMALLINT NOT NULL,
            numero_semana TINYINT NOT NULL,
            fecha_inicio_semana DATE NOT NULL,
            fecha_fin_semana DATE NOT NULL,
            anio_corte SMALLINT NOT NULL,
            mes_corte TINYINT NOT NULL,
            fecha_inicio_tramo DATE NOT NULL,
            fecha_fin_tramo DATE NOT NULL,
            total_carpetas INT NOT NULL CONSTRAINT DF_semanal_carga_bloque_carpetas DEFAULT (0),
            total_delitos INT NOT NULL CONSTRAINT DF_semanal_carga_bloque_delitos DEFAULT (0),
            total_victimas INT NOT NULL CONSTRAINT DF_semanal_carga_bloque_victimas DEFAULT (0),
            reemplaza_informacion BIT NOT NULL CONSTRAINT DF_semanal_carga_bloque_reemplaza DEFAULT (0),
            estado NVARCHAR(50) NOT NULL CONSTRAINT DF_semanal_carga_bloque_estado DEFAULT (N'VALIDADO_PENDIENTE'),
            fecha_registro DATETIME2(0) NOT NULL CONSTRAINT DF_semanal_carga_bloque_fecha DEFAULT (SYSDATETIME()),
            activo BIT NOT NULL CONSTRAINT DF_semanal_carga_bloque_activo DEFAULT (1),

            CONSTRAINT PK_semanal_carga_bloque
                PRIMARY KEY (id_semanal_carga_bloque),

            CONSTRAINT UQ_semanal_carga_bloque_carga_periodo
                UNIQUE
                (
                    id_semanal_carga,
                    anio_semana,
                    numero_semana,
                    anio_corte,
                    mes_corte
                ),

            CONSTRAINT FK_semanal_carga_bloque_carga
                FOREIGN KEY (id_semanal_carga)
                REFERENCES dbo.semanal_carga(id_semanal_carga),

            CONSTRAINT FK_semanal_carga_bloque_entidad
                FOREIGN KEY (id_entidad_federativa)
                REFERENCES dbo.catalogo_entidad_federativa(id_entidad_federativa),

            CONSTRAINT CK_semanal_carga_bloque_anio_semana
                CHECK (anio_semana BETWEEN 2000 AND 9999),

            CONSTRAINT CK_semanal_carga_bloque_numero_semana
                CHECK (numero_semana BETWEEN 1 AND 53),

            CONSTRAINT CK_semanal_carga_bloque_anio_corte
                CHECK (anio_corte BETWEEN 2000 AND 9999),

            CONSTRAINT CK_semanal_carga_bloque_mes_corte
                CHECK (mes_corte BETWEEN 1 AND 12),

            CONSTRAINT CK_semanal_carga_bloque_totales
                CHECK
                (
                    total_carpetas >= 0
                    AND total_delitos >= 0
                    AND total_victimas >= 0
                ),

            CONSTRAINT CK_semanal_carga_bloque_fechas
                CHECK
                (
                    DATEDIFF(DAY, fecha_inicio_semana, fecha_fin_semana) = 6
                    AND fecha_inicio_tramo BETWEEN fecha_inicio_semana AND fecha_fin_semana
                    AND fecha_fin_tramo BETWEEN fecha_inicio_semana AND fecha_fin_semana
                    AND fecha_inicio_tramo <= fecha_fin_tramo
                    AND YEAR(fecha_inicio_tramo) = anio_corte
                    AND YEAR(fecha_fin_tramo) = anio_corte
                    AND MONTH(fecha_inicio_tramo) = mes_corte
                    AND MONTH(fecha_fin_tramo) = mes_corte
                )
        );
    END;

    INSERT INTO dbo.semanal_carga_bloque
    (
        id_semanal_carga,
        id_entidad_federativa,
        anio_semana,
        numero_semana,
        fecha_inicio_semana,
        fecha_fin_semana,
        anio_corte,
        mes_corte,
        fecha_inicio_tramo,
        fecha_fin_tramo,
        total_carpetas,
        total_delitos,
        total_victimas,
        reemplaza_informacion,
        estado,
        fecha_registro,
        activo
    )
    SELECT
        sc.id_semanal_carga,
        sc.id_entidad_federativa,
        sc.anio_semana,
        sc.numero_semana,
        sc.fecha_inicio_semana,
        sc.fecha_fin_semana,
        sc.anio_corte,
        sc.mes_corte,
        sc.fecha_inicio_tramo,
        sc.fecha_fin_tramo,
        sc.total_carpetas_incluidas,
        sc.total_delitos_incluidos,
        sc.total_victimas_incluidas,
        CASE
            WHEN sc.tipo_carga = N'ACTUALIZACION' THEN 1
            ELSE 0
        END,
        sc.estado,
        sc.fecha_validacion,
        sc.activo
    FROM dbo.semanal_carga sc
    WHERE sc.id_entidad_federativa IS NOT NULL
      AND sc.tipo_carga IN (N'CARGA_INICIAL', N'ACTUALIZACION')
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.semanal_carga_bloque bloque
          WHERE bloque.id_semanal_carga = sc.id_semanal_carga
            AND bloque.anio_semana = sc.anio_semana
            AND bloque.numero_semana = sc.numero_semana
            AND bloque.anio_corte = sc.anio_corte
            AND bloque.mes_corte = sc.mes_corte
      );

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.semanal_carga_bloque')
          AND name = N'IX_semanal_carga_bloque_entidad_periodo'
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_semanal_carga_bloque_entidad_periodo
        ON dbo.semanal_carga_bloque
        (
            id_entidad_federativa,
            anio_corte,
            mes_corte,
            fecha_inicio_tramo,
            fecha_fin_tramo
        )
        INCLUDE
        (
            id_semanal_carga,
            anio_semana,
            numero_semana,
            reemplaza_informacion,
            estado
        )
        WHERE activo = 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.semanal_carga_bloque')
          AND name = N'UX_semanal_carga_bloque_pendiente'
    )
    BEGIN
        CREATE UNIQUE NONCLUSTERED INDEX UX_semanal_carga_bloque_pendiente
        ON dbo.semanal_carga_bloque
        (
            id_entidad_federativa,
            anio_semana,
            numero_semana,
            anio_corte,
            mes_corte
        )
        WHERE activo = 1
          AND estado IN
          (
              N'VALIDADO_PENDIENTE',
              N'VALIDADO_PENDIENTE_ACTUALIZACION',
              N'PENDIENTE_APROBACION'
          );
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
    BEGIN
        ROLLBACK TRANSACTION;
    END;

    THROW;
END CATCH;

SELECT
    OBJECT_SCHEMA_NAME(object_id) AS esquema,
    name AS tabla,
    create_date AS fecha_creacion
FROM sys.tables
WHERE object_id = OBJECT_ID(N'dbo.semanal_carga_bloque');

SELECT
    COUNT_BIG(DISTINCT sc.id_semanal_carga) AS cargas_semanales,
    COUNT_BIG(bloque.id_semanal_carga_bloque) AS bloques_registrados,
    COUNT_BIG
    (
        DISTINCT CASE
            WHEN bloque.id_semanal_carga_bloque IS NULL
                THEN sc.id_semanal_carga
        END
    ) AS cargas_sin_bloque
FROM dbo.semanal_carga sc
LEFT JOIN dbo.semanal_carga_bloque bloque
    ON bloque.id_semanal_carga = sc.id_semanal_carga
WHERE sc.tipo_carga IN (N'CARGA_INICIAL', N'ACTUALIZACION');

SELECT
    name AS indice,
    is_unique,
    has_filter,
    filter_definition
FROM sys.indexes
WHERE object_id = OBJECT_ID(N'dbo.semanal_carga_bloque')
ORDER BY index_id;