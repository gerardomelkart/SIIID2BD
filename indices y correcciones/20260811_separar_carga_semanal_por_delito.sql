USE siiid2;
GO

IF COL_LENGTH(N'dbo.semanal_carga', N'id_delito') IS NULL
BEGIN
    ALTER TABLE dbo.semanal_carga ADD id_delito INT NULL;
END;
GO

SELECT COL_LENGTH(N'dbo.semanal_carga', N'id_delito') AS columna_creada;
GO


USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.semanal_carga', N'U') IS NULL
    BEGIN
        THROW 50010, 'No existe la tabla dbo.semanal_carga.', 1;
    END;

    IF COL_LENGTH(N'dbo.semanal_carga', N'id_delito') IS NULL
    BEGIN
        ALTER TABLE dbo.semanal_carga ADD id_delito INT NULL;
    END;

    ;WITH DelitosPorCarga AS
    (
        SELECT
            origen.id_semanal_carga,
            MIN(origen.id_delito) AS id_delito,
            COUNT(*) AS cantidad_delitos
        FROM
        (
            SELECT DISTINCT
                d.id_semanal_carga,
                d.id_catalogo_delito AS id_delito
            FROM dbo.semanal_delito d
            WHERE d.id_catalogo_delito IS NOT NULL

            UNION

            SELECT DISTINCT
                tmp.id_semanal_carga,
                sd.id_delito
            FROM dbo.semanal_carga_tmp_delito tmp
            INNER JOIN dbo.catalogo_modalidad_delito md ON md.clave4 = LTRIM(RTRIM(tmp.clasf_de_dto))
            INNER JOIN dbo.catalogo_subtipo_delito sd ON sd.id_subtipo_delito = md.id_subtipo_delito
            WHERE tmp.incluido = 1
              AND tmp.activo = 1
        ) origen
        GROUP BY origen.id_semanal_carga
    )
    UPDATE sc
    SET id_delito = delitos.id_delito
    FROM dbo.semanal_carga sc
    INNER JOIN DelitosPorCarga delitos ON delitos.id_semanal_carga = sc.id_semanal_carga
    WHERE sc.id_delito IS NULL
      AND delitos.cantidad_delitos = 1;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.foreign_keys
        WHERE name = N'FK_semanal_carga_catalogo_delito'
          AND parent_object_id = OBJECT_ID(N'dbo.semanal_carga')
    )
    BEGIN
        ALTER TABLE dbo.semanal_carga WITH CHECK
        ADD CONSTRAINT FK_semanal_carga_catalogo_delito
        FOREIGN KEY (id_delito) REFERENCES dbo.catalogo_delito(id_delito);
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'dbo.semanal_carga')
          AND name = N'IX_semanal_carga_identidad_delito'
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_semanal_carga_identidad_delito
        ON dbo.semanal_carga
        (
            id_entidad_federativa,
            id_usuario_carga,
            id_delito,
            estado,
            activo
        )
        INCLUDE
        (
            id_semanal_carga,
            codigo_referencia,
            fecha_validacion,
            fecha_confirmacion
        );
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

SELECT
    sc.id_semanal_carga,
    sc.codigo_referencia,
    sc.tipo_carga,
    sc.estado,
    sc.id_delito,
    cd.delito
FROM dbo.semanal_carga sc
LEFT JOIN dbo.catalogo_delito cd ON cd.id_delito = sc.id_delito
WHERE sc.activo = 1
ORDER BY sc.id_semanal_carga DESC;
GO