USE [siiid2];
GO

IF OBJECT_ID(N'dbo.api_feminicidios_bitacora', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.api_feminicidios_bitacora
    (
        id_bitacora     bigint IDENTITY(1,1) NOT NULL,
        fecha_utc       datetime2(3) NOT NULL,
        evento          varchar(10) NOT NULL,
        origen          varchar(10) NULL,
        id_usuario      int NULL,
        usuario         nvarchar(100) NULL,
        ip              varchar(45) NULL,
        trace_id        nvarchar(128) NOT NULL,
        estado_http     int NOT NULL,
        anio            int NULL,
        mes             int NULL,
        formato         varchar(4) NULL,
        total_registros int NULL,
        duracion_ms     bigint NOT NULL,

        CONSTRAINT PK_api_feminicidios_bitacora
            PRIMARY KEY CLUSTERED (id_bitacora),

        CONSTRAINT CK_api_feminicidios_bitacora_evento
            CHECK (evento IN ('LOGIN', 'CONSULTA')),

        CONSTRAINT CK_api_feminicidios_bitacora_origen
            CHECK (origen IN ('EXTERNO', 'SIIID')),

        CONSTRAINT CK_api_feminicidios_bitacora_formato
            CHECK (formato IN ('json', 'xlsx'))
    );

    CREATE INDEX IX_api_feminicidios_bitacora_fecha
        ON dbo.api_feminicidios_bitacora (fecha_utc DESC);

    CREATE INDEX IX_api_feminicidios_bitacora_usuario
        ON dbo.api_feminicidios_bitacora
            (origen, id_usuario, fecha_utc DESC)
        INCLUDE (evento, estado_http, anio, mes, formato);
END;
GO