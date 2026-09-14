USE [siiid2];
GO

DECLARE @DefaultNoBanci SYSNAME;

SELECT @DefaultNoBanci = dc.name
FROM sys.default_constraints dc
INNER JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id
WHERE dc.parent_object_id = OBJECT_ID(N'dbo.banci_victima')
  AND c.name = N'no_banci';

IF @DefaultNoBanci IS NOT NULL
    EXEC(N'ALTER TABLE dbo.banci_victima DROP CONSTRAINT [' + @DefaultNoBanci + N'];');
GO

ALTER TABLE dbo.banci_victima ALTER COLUMN no_banci BIGINT NULL;
GO

IF OBJECT_ID(N'dbo.seq_banci_no_banci', N'SO') IS NOT NULL
    DROP SEQUENCE dbo.seq_banci_no_banci;
GO