USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'dbo.semanal_carga_tmp_carpeta', N'U') IS NULL
       OR OBJECT_ID(N'dbo.semanal_carpeta_investigacion', N'U') IS NULL
       OR OBJECT_ID(N'dbo.semanal_carpeta_investigacion_historico', N'U') IS NULL
    BEGIN
        THROW 50010, 'No se encontró la estructura completa del módulo semanal.', 1;
    END;

    IF COL_LENGTH(N'dbo.semanal_carga_tmp_carpeta', N'denuncia_anonima') IS NULL ALTER TABLE dbo.semanal_carga_tmp_carpeta ADD denuncia_anonima NVARCHAR(20) NULL;
    IF COL_LENGTH(N'dbo.semanal_carga_tmp_carpeta', N'denuncia_anonima_089') IS NULL ALTER TABLE dbo.semanal_carga_tmp_carpeta ADD denuncia_anonima_089 NVARCHAR(20) NULL;
    IF COL_LENGTH(N'dbo.semanal_carga_tmp_carpeta', N'denuncia_anonima_otro_medio') IS NULL ALTER TABLE dbo.semanal_carga_tmp_carpeta ADD denuncia_anonima_otro_medio NVARCHAR(500) NULL;

    IF COL_LENGTH(N'dbo.semanal_carpeta_investigacion', N'denuncia_anonima') IS NULL ALTER TABLE dbo.semanal_carpeta_investigacion ADD denuncia_anonima NVARCHAR(20) NULL;
    IF COL_LENGTH(N'dbo.semanal_carpeta_investigacion', N'denuncia_anonima_089') IS NULL ALTER TABLE dbo.semanal_carpeta_investigacion ADD denuncia_anonima_089 NVARCHAR(20) NULL;
    IF COL_LENGTH(N'dbo.semanal_carpeta_investigacion', N'denuncia_anonima_otro_medio') IS NULL ALTER TABLE dbo.semanal_carpeta_investigacion ADD denuncia_anonima_otro_medio NVARCHAR(500) NULL;

    IF COL_LENGTH(N'dbo.semanal_carpeta_investigacion_historico', N'denuncia_anonima') IS NULL ALTER TABLE dbo.semanal_carpeta_investigacion_historico ADD denuncia_anonima NVARCHAR(20) NULL;
    IF COL_LENGTH(N'dbo.semanal_carpeta_investigacion_historico', N'denuncia_anonima_089') IS NULL ALTER TABLE dbo.semanal_carpeta_investigacion_historico ADD denuncia_anonima_089 NVARCHAR(20) NULL;
    IF COL_LENGTH(N'dbo.semanal_carpeta_investigacion_historico', N'denuncia_anonima_otro_medio') IS NULL ALTER TABLE dbo.semanal_carpeta_investigacion_historico ADD denuncia_anonima_otro_medio NVARCHAR(500) NULL;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

SELECT
    OBJECT_NAME(c.object_id) AS tabla,
    c.name AS columna,
    t.name AS tipo,
    c.max_length,
    c.is_nullable
FROM sys.columns c
INNER JOIN sys.types t ON t.user_type_id = c.user_type_id
WHERE c.object_id IN
(
    OBJECT_ID(N'dbo.semanal_carga_tmp_carpeta'),
    OBJECT_ID(N'dbo.semanal_carpeta_investigacion'),
    OBJECT_ID(N'dbo.semanal_carpeta_investigacion_historico')
)
AND c.name IN (N'denuncia_anonima', N'denuncia_anonima_089', N'denuncia_anonima_otro_medio')
ORDER BY tabla, c.column_id;
GO