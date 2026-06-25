USE siiid2;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -- Inserta usuarios del CSV y crea/actualiza su registro en habilita_carga_modificacion.
    -- Contraseña temporal para todos: password123
    -- Regla usada: roles 1 y 2 => habilita_carga=1 y habilita_modificacion=1; rol 3 => 0 y 0.

    -- 1. AABJ791121V65
    DECLARE @id_usuario_actual INT;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'AABJ791121V65';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'AABJ791121V65', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'JESUS RAFAEL', N'ALMANZA', N'BARRON',
            N'jesus.almanza@sspc.gob.mx', N'AABJ791121V65', N'AABJ791121HDFLRS01', N'5533322748', 9,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 1, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'JESUS RAFAEL',
            primer_apellido = N'ALMANZA',
            segundo_apellido = N'BARRON',
            correo_electronico = N'jesus.almanza@sspc.gob.mx',
            rfc = N'AABJ791121V65',
            curp = N'AABJ791121HDFLRS01',
            telefono_contacto = N'5533322748',
            id_entidad_federativa = 9,
            id_rol = 1,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 2. GARM850325V65
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'GARM850325V65';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'GARM850325V65', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'MARCOS', N'GARCIA', N'ROJAS',
            N'garcia.marcos@gmail.com', N'GARM850325V65', N'GARM850325HDFLRS01', N'5533326587', 2,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'MARCOS',
            primer_apellido = N'GARCIA',
            segundo_apellido = N'ROJAS',
            correo_electronico = N'garcia.marcos@gmail.com',
            rfc = N'GARM850325V65',
            curp = N'GARM850325HDFLRS01',
            telefono_contacto = N'5533326587',
            id_entidad_federativa = 2,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 3. MERA850706V64
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'MERA850706V64';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'MERA850706V64', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'ALEJANDRO', N'MEDINA', N'ROJAS',
            N'alex.pba@gmail.com', N'MERA850706V64', N'MERA850706HDFLRS00', N'5533322584', 1,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 3, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'ALEJANDRO',
            primer_apellido = N'MEDINA',
            segundo_apellido = N'ROJAS',
            correo_electronico = N'alex.pba@gmail.com',
            rfc = N'MERA850706V64',
            curp = N'MERA850706HDFLRS00',
            telefono_contacto = N'5533322584',
            id_entidad_federativa = 1,
            id_rol = 3,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 0,
            habilita_modificacion = 0,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (0, 0, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 4. AGSX25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'AGSX25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'AGSX25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'AGUASCALIENTES', N'USUARIO', N'PRUEBA',
            N'cni@sspc.gob.mx', N'XAXX010101AAB', N'XAXX010101HDFXXXA2', N'5611036000', 1,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'AGUASCALIENTES',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'cni@sspc.gob.mx',
            rfc = N'XAXX010101AAB',
            curp = N'XAXX010101HDFXXXA2',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 1,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 5. BCXX25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'BCXX25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'BCXX25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'BAJA CALIFORNIA', N'USUARIO', N'PRUEBA',
            N'bcxx25052300@sspc.gob.mx', N'XAXX010101AAD', N'XAXX010101HDFXXXA4', N'5611036000', 2,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'BAJA CALIFORNIA',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'bcxx25052300@sspc.gob.mx',
            rfc = N'XAXX010101AAD',
            curp = N'XAXX010101HDFXXXA4',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 2,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 6. BCSX25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'BCSX25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'BCSX25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'BAJA CALIFORNIA SUR', N'USUARIO', N'PRUEBA',
            N'bcsx25052300@sspc.gob.mx', N'XAXX010101AAF', N'XAXX010101HDFXXXA6', N'5611036000', 3,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'BAJA CALIFORNIA SUR',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'bcsx25052300@sspc.gob.mx',
            rfc = N'XAXX010101AAF',
            curp = N'XAXX010101HDFXXXA6',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 3,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 7. CAMX25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'CAMX25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'CAMX25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'CAMPECHE', N'USUARIO', N'PRUEBA',
            N'camx25052300@sspc.gob.mx', N'XAXX010101AAH', N'XAXX010101HDFXXXA8', N'5611036000', 4,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'CAMPECHE',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'camx25052300@sspc.gob.mx',
            rfc = N'XAXX010101AAH',
            curp = N'XAXX010101HDFXXXA8',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 4,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 8. CHPX25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'CHPX25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'CHPX25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'CHIAPAS', N'USUARIO', N'PRUEBA',
            N'chpx25052300@sspc.gob.mx', N'XAXX010101AAJ', N'XAXX010101HDFXXXB0', N'5611036000', 7,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'CHIAPAS',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'chpx25052300@sspc.gob.mx',
            rfc = N'XAXX010101AAJ',
            curp = N'XAXX010101HDFXXXB0',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 7,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 9. CHIX25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'CHIX25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'CHIX25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'CHIHUAHUA', N'USUARIO', N'PRUEBA',
            N'chix25052300@sspc.gob.mx', N'XAXX010101AAL', N'XAXX010101HDFXXXB2', N'5611036000', 8,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'CHIHUAHUA',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'chix25052300@sspc.gob.mx',
            rfc = N'XAXX010101AAL',
            curp = N'XAXX010101HDFXXXB2',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 8,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 10. COAX25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'COAX25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'COAX25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'COAHUILA', N'USUARIO', N'PRUEBA',
            N'coax25052300@sspc.gob.mx', N'XAXX010101AAN', N'XAXX010101HDFXXXB4', N'5611036000', 5,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'COAHUILA',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'coax25052300@sspc.gob.mx',
            rfc = N'XAXX010101AAN',
            curp = N'XAXX010101HDFXXXB4',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 5,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 11. COLX25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'COLX25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'COLX25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'COLIMA', N'USUARIO', N'PRUEBA',
            N'colx25052300@sspc.gob.mx', N'XAXX010101AAP', N'XAXX010101HDFXXXB6', N'5611036000', 6,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'COLIMA',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'colx25052300@sspc.gob.mx',
            rfc = N'XAXX010101AAP',
            curp = N'XAXX010101HDFXXXB6',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 6,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 12. CDMX25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'CDMX25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'CDMX25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'CIUDAD DE MEXICO', N'USUARIO', N'PRUEBA',
            N'cdmx25052300@sspc.gob.mx', N'XAXX010101AAR', N'XAXX010101HDFXXXB8', N'5611036000', 9,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'CIUDAD DE MEXICO',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'cdmx25052300@sspc.gob.mx',
            rfc = N'XAXX010101AAR',
            curp = N'XAXX010101HDFXXXB8',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 9,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 13. DURX25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'DURX25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'DURX25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'DURANGO', N'USUARIO', N'PRUEBA',
            N'durx25052300@sspc.gob.mx', N'XAXX010101AAT', N'XAXX010101HDFXXXC0', N'5611036000', 10,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'DURANGO',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'durx25052300@sspc.gob.mx',
            rfc = N'XAXX010101AAT',
            curp = N'XAXX010101HDFXXXC0',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 10,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 14. GTOX25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'GTOX25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'GTOX25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'GUANAJUATO', N'USUARIO', N'PRUEBA',
            N'gtox25052300@sspc.gob.mx', N'XAXX010101AAV', N'XAXX010101HDFXXXC2', N'5611036000', 11,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'GUANAJUATO',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'gtox25052300@sspc.gob.mx',
            rfc = N'XAXX010101AAV',
            curp = N'XAXX010101HDFXXXC2',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 11,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 15. GROX25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'GROX25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'GROX25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'GUERRERO', N'USUARIO', N'PRUEBA',
            N'grox25052300@sspc.gob.mx', N'XAXX010101AAX', N'XAXX010101HDFXXXC4', N'5611036000', 12,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'GUERRERO',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'grox25052300@sspc.gob.mx',
            rfc = N'XAXX010101AAX',
            curp = N'XAXX010101HDFXXXC4',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 12,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 16. HGOX25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'HGOX25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'HGOX25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'HIDALGO', N'USUARIO', N'PRUEBA',
            N'hgox25052300@sspc.gob.mx', N'XAXX010101AAZ', N'XAXX010101HDFXXXC6', N'5611036000', 13,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'HIDALGO',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'hgox25052300@sspc.gob.mx',
            rfc = N'XAXX010101AAZ',
            curp = N'XAXX010101HDFXXXC6',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 13,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 17. JALX25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'JALX25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'JALX25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'JALISCO', N'USUARIO', N'PRUEBA',
            N'jalx25052300@sspc.gob.mx', N'XAXX010101AA1', N'XAXX010101HDFXXXC8', N'5611036000', 14,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'JALISCO',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'jalx25052300@sspc.gob.mx',
            rfc = N'XAXX010101AA1',
            curp = N'XAXX010101HDFXXXC8',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 14,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 18. MEXX25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'MEXX25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'MEXX25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'ESTADO DE MEXICO', N'USUARIO', N'PRUEBA',
            N'mexx25052300@sspc.gob.mx', N'XAXX010101AA3', N'XAXX010101HDFXXXD0', N'5611036000', 15,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'ESTADO DE MEXICO',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'mexx25052300@sspc.gob.mx',
            rfc = N'XAXX010101AA3',
            curp = N'XAXX010101HDFXXXD0',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 15,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 19. MICH25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'MICH25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'MICH25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'MICHOACAN', N'USUARIO', N'PRUEBA',
            N'mich25052300@sspc.gob.mx', N'XAXX010101AA5', N'XAXX010101HDFXXXD2', N'5611036000', 16,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'MICHOACAN',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'mich25052300@sspc.gob.mx',
            rfc = N'XAXX010101AA5',
            curp = N'XAXX010101HDFXXXD2',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 16,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 20. MOR25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'MOR25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'MOR25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'MORELOS', N'USUARIO', N'PRUEBA',
            N'mor25052300@sspc.gob.mx', N'XAXX010101AA7', N'XAXX010101HDFXXXD4', N'5611036000', 17,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'MORELOS',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'mor25052300@sspc.gob.mx',
            rfc = N'XAXX010101AA7',
            curp = N'XAXX010101HDFXXXD4',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 17,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 21. NAYX25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'NAYX25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'NAYX25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'NAYARIT', N'USUARIO', N'PRUEBA',
            N'nayx25052300@sspc.gob.mx', N'XAXX010101AA9', N'XAXX010101HDFXXXD6', N'5611036000', 18,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'NAYARIT',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'nayx25052300@sspc.gob.mx',
            rfc = N'XAXX010101AA9',
            curp = N'XAXX010101HDFXXXD6',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 18,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 22. NLXX25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'NLXX25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'NLXX25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'NUEVO LEON', N'USUARIO', N'PRUEBA',
            N'nlxx25052300@sspc.gob.mx', N'XAXX010101ABB', N'XAXX010101HDFXXXD8', N'5611036000', 19,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'NUEVO LEON',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'nlxx25052300@sspc.gob.mx',
            rfc = N'XAXX010101ABB',
            curp = N'XAXX010101HDFXXXD8',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 19,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 23. OAXX25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'OAXX25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'OAXX25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'OAXACA', N'USUARIO', N'PRUEBA',
            N'oaxx25052300@sspc.gob.mx', N'XAXX010101ABD', N'XAXX010101HDFXXXE0', N'5611036000', 20,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'OAXACA',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'oaxx25052300@sspc.gob.mx',
            rfc = N'XAXX010101ABD',
            curp = N'XAXX010101HDFXXXE0',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 20,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 24. PUEX25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'PUEX25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'PUEX25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'PUEBLA', N'USUARIO', N'PRUEBA',
            N'puex25052300@sspc.gob.mx', N'XAXX010101ABF', N'XAXX010101HDFXXXE2', N'5611036000', 21,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'PUEBLA',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'puex25052300@sspc.gob.mx',
            rfc = N'XAXX010101ABF',
            curp = N'XAXX010101HDFXXXE2',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 21,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 25. QROX25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'QROX25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'QROX25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'QUERETARO', N'USUARIO', N'PRUEBA',
            N'qrox25052300@sspc.gob.mx', N'XAXX010101ABH', N'XAXX010101HDFXXXE4', N'5611036000', 22,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'QUERETARO',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'qrox25052300@sspc.gob.mx',
            rfc = N'XAXX010101ABH',
            curp = N'XAXX010101HDFXXXE4',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 22,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 26. RROX25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'RROX25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'RROX25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'QUINTANA ROO', N'USUARIO', N'PRUEBA',
            N'rrox25052300@sspc.gob.mx', N'XAXX010101ABJ', N'XAXX010101HDFXXXE6', N'5611036000', 23,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'QUINTANA ROO',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'rrox25052300@sspc.gob.mx',
            rfc = N'XAXX010101ABJ',
            curp = N'XAXX010101HDFXXXE6',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 23,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 27. SLPX25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'SLPX25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'SLPX25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'SAN LUIS POTOSI', N'USUARIO', N'PRUEBA',
            N'slpx25052300@sspc.gob.mx', N'XAXX010101ABL', N'XAXX010101HDFXXXE8', N'5611036000', 24,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'SAN LUIS POTOSI',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'slpx25052300@sspc.gob.mx',
            rfc = N'XAXX010101ABL',
            curp = N'XAXX010101HDFXXXE8',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 24,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 28. SINX25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'SINX25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'SINX25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'SINALOA', N'USUARIO', N'PRUEBA',
            N'sinx25052300@sspc.gob.mx', N'XAXX010101ABN', N'XAXX010101HDFXXXF0', N'5611036000', 25,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'SINALOA',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'sinx25052300@sspc.gob.mx',
            rfc = N'XAXX010101ABN',
            curp = N'XAXX010101HDFXXXF0',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 25,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 29. SONX25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'SONX25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'SONX25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'SONORA', N'USUARIO', N'PRUEBA',
            N'sonx25052300@sspc.gob.mx', N'XAXX010101ABP', N'XAXX010101HDFXXXF2', N'5611036000', 26,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'SONORA',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'sonx25052300@sspc.gob.mx',
            rfc = N'XAXX010101ABP',
            curp = N'XAXX010101HDFXXXF2',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 26,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 30. TABX25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'TABX25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'TABX25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'TABASCO', N'USUARIO', N'PRUEBA',
            N'tabx25052300@sspc.gob.mx', N'XAXX010101ABR', N'XAXX010101HDFXXXF4', N'5611036000', 27,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'TABASCO',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'tabx25052300@sspc.gob.mx',
            rfc = N'XAXX010101ABR',
            curp = N'XAXX010101HDFXXXF4',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 27,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 31. TAMX25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'TAMX25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'TAMX25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'TAMAULIPAS', N'USUARIO', N'PRUEBA',
            N'tamx25052300@sspc.gob.mx', N'XAXX010101ABT', N'XAXX010101HDFXXXF6', N'5611036000', 28,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'TAMAULIPAS',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'tamx25052300@sspc.gob.mx',
            rfc = N'XAXX010101ABT',
            curp = N'XAXX010101HDFXXXF6',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 28,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 32. TLAX25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'TLAX25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'TLAX25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'TLAXCALA', N'USUARIO', N'PRUEBA',
            N'tlax25052300@sspc.gob.mx', N'XAXX010101ABV', N'XAXX010101HDFXXXF8', N'5611036000', 29,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'TLAXCALA',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'tlax25052300@sspc.gob.mx',
            rfc = N'XAXX010101ABV',
            curp = N'XAXX010101HDFXXXF8',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 29,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 33. VERX25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'VERX25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'VERX25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'VERACRUZ', N'USUARIO', N'PRUEBA',
            N'verx25052300@sspc.gob.mx', N'XAXX010101ABX', N'XAXX010101HDFXXXG0', N'5611036000', 30,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'VERACRUZ',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'verx25052300@sspc.gob.mx',
            rfc = N'XAXX010101ABX',
            curp = N'XAXX010101HDFXXXG0',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 30,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 34. YUCX25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'YUCX25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'YUCX25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'YUCATAN', N'USUARIO', N'PRUEBA',
            N'yucx25052300@sspc.gob.mx', N'XAXX010101ABZ', N'XAXX010101HDFXXXG2', N'5611036000', 31,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'YUCATAN',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'yucx25052300@sspc.gob.mx',
            rfc = N'XAXX010101ABZ',
            curp = N'XAXX010101HDFXXXG2',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 31,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 35. ZACX25052300
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'ZACX25052300';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'ZACX25052300', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'ZACATECAS', N'USUARIO', N'PRUEBA',
            N'zacx25052300@sspc.gob.mx', N'XAXX010101AB1', N'XAXX010101HDFXXXG4', N'5611036000', 32,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'ZACATECAS',
            primer_apellido = N'USUARIO',
            segundo_apellido = N'PRUEBA',
            correo_electronico = N'zacx25052300@sspc.gob.mx',
            rfc = N'XAXX010101AB1',
            curp = N'XAXX010101HDFXXXG4',
            telefono_contacto = N'5611036000',
            id_entidad_federativa = 32,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 36. SACR840613TR9
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'SACR840613TR9';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'SACR840613TR9', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'RODRIGO ANTONIO', N'SÁNCHEZ', N'CASTELLANOS',
            N'rodrigosc13@gmail.com', N'SACR840613TR9', N'XAXX010101HDFXXXG5', NULL, 9,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 1, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'RODRIGO ANTONIO',
            primer_apellido = N'SÁNCHEZ',
            segundo_apellido = N'CASTELLANOS',
            correo_electronico = N'rodrigosc13@gmail.com',
            rfc = N'SACR840613TR9',
            curp = N'XAXX010101HDFXXXG5',
            telefono_contacto = NULL,
            id_entidad_federativa = 9,
            id_rol = 1,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    -- 37. MOBJ960201KR8
    SET @id_usuario_actual = NULL;
    SELECT @id_usuario_actual = id_usuario FROM usuario WHERE usuario = N'MOBJ960201KR8';

    IF @id_usuario_actual IS NULL
    BEGIN
        INSERT INTO usuario (
            usuario, [password], nombre, primer_apellido, segundo_apellido,
            correo_electronico, rfc, curp, telefono_contacto, id_entidad_federativa,
            fecha_alta, fecha_modificacion, id_usuario_alta, id_usuario_modificacion, id_rol, activo
        )
        VALUES (
            N'MOBJ960201KR8', N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu', N'JESÚS RICARDO', N'MORALES', N'BOCANEGRA',
            N'jesus.moralesb@sspc.gob.mx', N'MOBJ960201KR8', N'XAXX010101HDFXXXG6', NULL, 9,
            SYSDATETIME(), SYSDATETIME(), 1, 1, 2, 1
        );

        SET @id_usuario_actual = CONVERT(INT, SCOPE_IDENTITY());
    END
    ELSE
    BEGIN
        UPDATE usuario
        SET
            [password] = N'$2a$12$/RU/3auctujFR0EPl.EOVeeJsYCWAYCpsX3zgnW/9WxAkdhun.2Bu',
            nombre = N'JESÚS RICARDO',
            primer_apellido = N'MORALES',
            segundo_apellido = N'BOCANEGRA',
            correo_electronico = N'jesus.moralesb@sspc.gob.mx',
            rfc = N'MOBJ960201KR8',
            curp = N'XAXX010101HDFXXXG6',
            telefono_contacto = NULL,
            id_entidad_federativa = 9,
            id_rol = 2,
            id_usuario_modificacion = 1,
            fecha_modificacion = SYSDATETIME(),
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END

    IF EXISTS (SELECT 1 FROM habilita_carga_modificacion WHERE id_usuario = @id_usuario_actual)
    BEGIN
        UPDATE habilita_carga_modificacion
        SET habilita_carga = 1,
            habilita_modificacion = 1,
            activo = 1
        WHERE id_usuario = @id_usuario_actual;
    END
    ELSE
    BEGIN
        INSERT INTO habilita_carga_modificacion (habilita_carga, habilita_modificacion, id_usuario, activo)
        VALUES (1, 1, @id_usuario_actual, 1);
    END

    SET @id_usuario_actual = NULL;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    SELECT
        ERROR_NUMBER() AS numero_error,
        ERROR_MESSAGE() AS mensaje_error,
        ERROR_LINE() AS linea_error;

    THROW;
END CATCH;
GO