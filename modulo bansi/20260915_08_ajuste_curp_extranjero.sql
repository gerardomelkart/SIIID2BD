USE [siiid2];
GO

IF COL_LENGTH(N'dbo.banci_victima', N'curp') IS NOT NULL
    ALTER TABLE dbo.banci_victima ALTER COLUMN curp NVARCHAR(50) NULL;
GO