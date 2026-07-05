USE [siiid2];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF COL_LENGTH('dbo.delito', 'codigo_postal_fiscalia') IS NULL
BEGIN
    ALTER TABLE dbo.delito
    ADD codigo_postal_fiscalia NVARCHAR(50) NULL;
END;
GO

IF COL_LENGTH('dbo.delito_historico', 'codigo_postal_fiscalia') IS NULL
BEGIN
    ALTER TABLE dbo.delito_historico
    ADD codigo_postal_fiscalia NVARCHAR(50) NULL;
END;
GO

CREATE OR ALTER TRIGGER dbo.tr_delito_codigo_postal_fiscalia
ON dbo.delito
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted) AND UPDATE(codigo_postal_fiscalia)
    BEGIN
        RETURN;
    END;

    UPDATE de
    SET de.codigo_postal_fiscalia = origen.codigo_postal_fiscalia
    FROM dbo.delito de
    INNER JOIN inserted i
        ON i.id_delito = de.id_delito
    INNER JOIN dbo.carpeta_investigacion ci
        ON ci.id_carpeta_investigacion = de.id_carpeta_investigacion
    CROSS APPLY
    (
        SELECT TOP 1
            NULLIF(LTRIM(RTRIM(tmp.cp)), N'') AS codigo_postal_fiscalia
        FROM dbo.carga_tmp_delito tmp
        WHERE tmp.id_carga = de.id_carga
          AND tmp.id_ci = ci.identificador_carpeta_fiscalia
          AND tmp.id_delito = de.identificador_delito_fiscalia
    ) origen
    WHERE ISNULL(de.codigo_postal_fiscalia, N'') <> ISNULL(origen.codigo_postal_fiscalia, N'');
END;
GO

CREATE OR ALTER TRIGGER dbo.tr_delito_historico_codigo_postal_fiscalia
ON dbo.delito_historico
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dh
    SET dh.codigo_postal_fiscalia = de.codigo_postal_fiscalia
    FROM dbo.delito_historico dh
    INNER JOIN inserted i
        ON i.id_delito = dh.id_delito
       AND ISNULL(i.id_carga_nueva, 0) = ISNULL(dh.id_carga_nueva, 0)
       AND ISNULL(i.tipo_movimiento, N'') = ISNULL(dh.tipo_movimiento, N'')
       AND i.fecha_modificacion = dh.fecha_modificacion
    INNER JOIN dbo.delito de
        ON de.id_delito = i.id_delito
    WHERE ISNULL(dh.codigo_postal_fiscalia, N'') <> ISNULL(de.codigo_postal_fiscalia, N'');
END;
GO
