USE [siiid2];
GO

DROP TRIGGER IF EXISTS dbo.tr_delito_codigo_postal_fiscalia;
DROP TRIGGER IF EXISTS dbo.tr_delito_historico_codigo_postal_fiscalia;
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
