USE [siiid2];
GO

IF EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE name = N'CK_banci_delito_coord_x'
      AND parent_object_id = OBJECT_ID(N'dbo.banci_delito')
)
    ALTER TABLE dbo.banci_delito DROP CONSTRAINT CK_banci_delito_coord_x;
GO

IF EXISTS
(
    SELECT 1
    FROM sys.check_constraints
    WHERE name = N'CK_banci_delito_coord_y'
      AND parent_object_id = OBJECT_ID(N'dbo.banci_delito')
)
    ALTER TABLE dbo.banci_delito DROP CONSTRAINT CK_banci_delito_coord_y;
GO