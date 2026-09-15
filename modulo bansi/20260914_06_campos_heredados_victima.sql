USE [siiid2];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

IF COL_LENGTH(N'dbo.banci_carga_tmp_victima', N'id_tv') IS NULL
    ALTER TABLE dbo.banci_carga_tmp_victima ADD id_tv NVARCHAR(100) NULL;
GO

IF COL_LENGTH(N'dbo.banci_carga_tmp_victima', N'id_tpm') IS NULL
    ALTER TABLE dbo.banci_carga_tmp_victima ADD id_tpm NVARCHAR(100) NULL;
GO

IF COL_LENGTH(N'dbo.banci_victima', N'id_tv') IS NULL
    ALTER TABLE dbo.banci_victima ADD id_tv TINYINT NULL;
GO

IF COL_LENGTH(N'dbo.banci_victima', N'id_tpm') IS NULL
    ALTER TABLE dbo.banci_victima ADD id_tpm TINYINT NULL;
GO

IF EXISTS
(
    SELECT 1
    FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'dbo.banci_victima')
      AND name = N'UQ_banci_victima_no_banci'
)
    ALTER TABLE dbo.banci_victima DROP CONSTRAINT UQ_banci_victima_no_banci;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.banci_victima')
      AND name = N'UX_banci_victima_no_banci'
)
    CREATE UNIQUE INDEX UX_banci_victima_no_banci
        ON dbo.banci_victima(no_banci)
        WHERE no_banci IS NOT NULL;
GO