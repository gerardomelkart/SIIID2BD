USE [siiid2];
GO

IF EXISTS
(
    SELECT 1
    FROM sys.foreign_keys
    WHERE name = N'FK_banci_victima_pob'
      AND parent_object_id = OBJECT_ID(N'dbo.banci_victima')
)
    ALTER TABLE dbo.banci_victima DROP CONSTRAINT FK_banci_victima_pob;
GO

IF EXISTS
(
    SELECT 1
    FROM sys.foreign_keys
    WHERE name = N'FK_banci_victima_disc'
      AND parent_object_id = OBJECT_ID(N'dbo.banci_victima')
)
    ALTER TABLE dbo.banci_victima DROP CONSTRAINT FK_banci_victima_disc;
GO