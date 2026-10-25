/* =====================================================================
   LA PROMESA ERP  |  14 - Autenticación (TEMPORAL hasta integrar)
   ---------------------------------------------------------------------
   Usuarios, roles y sesiones para operar los módulos de Compras con
   seguridad real (access token + refresh token + roles).
   Al integrar el login general del ERP se unifican con estas tablas.
     - Contraseñas: hash BCrypt generado por el backend (nunca texto plano).
     - Refresh tokens: se guarda solo el hash SHA-256, con expiración,
       revocación y rotación (cada renovación invalida el anterior).
     - Bloqueo temporal tras 5 intentos fallidos.
   Los usuarios de demostración los crea el backend al iniciar en
   Development, con la contraseña definida en user-secrets.
   ===================================================================== */
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
USE LaPromesaERP;
GO

IF SCHEMA_ID(N'seg') IS NULL EXEC (N'CREATE SCHEMA seg AUTHORIZATION dbo;');
GO

IF OBJECT_ID(N'seg.Roles', N'U') IS NULL
CREATE TABLE seg.Roles (
    IdRol        INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Roles PRIMARY KEY,
    Nombre       VARCHAR(30)    NOT NULL CONSTRAINT UQ_Roles_Nombre UNIQUE,
    Descripcion  NVARCHAR(200)  NULL
);
GO

MERGE seg.Roles AS t
USING (VALUES
    ('Administrador', N'Acceso total al sistema'),
    ('Compras',       N'Gestiona proveedores y crea/edita órdenes de compra'),
    ('Gerente',       N'Aprueba y anula órdenes; inactiva proveedores'),
    ('Bodega',        N'Registra recepciones de mercadería'),
    ('Tesoreria',     N'Registra pagos a proveedores'),
    ('Consulta',      N'Solo lectura y reportes')
) AS s (Nombre, Descripcion)
ON t.Nombre = s.Nombre
WHEN NOT MATCHED THEN INSERT (Nombre, Descripcion) VALUES (s.Nombre, s.Descripcion);
GO

IF OBJECT_ID(N'seg.Usuarios', N'U') IS NULL
CREATE TABLE seg.Usuarios (
    IdUsuario         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Usuarios PRIMARY KEY,
    Usuario           VARCHAR(50)    NOT NULL CONSTRAINT UQ_Usuarios_Usuario UNIQUE,
    NombreCompleto    NVARCHAR(150)  NOT NULL,
    Email             NVARCHAR(150)  NULL,
    PasswordHash      VARCHAR(100)   NOT NULL,
    IdRol             INT            NOT NULL CONSTRAINT FK_Usuarios_Roles REFERENCES seg.Roles (IdRol),
    Activo            BIT            NOT NULL CONSTRAINT DF_Usuarios_Activo   DEFAULT (1),
    IntentosFallidos  INT            NOT NULL CONSTRAINT DF_Usuarios_Intentos DEFAULT (0),
    BloqueadoHasta    DATETIME2(0)   NULL,
    UltimoAcceso      DATETIME2(0)   NULL,
    FechaCreacion     DATETIME2(0)   NOT NULL CONSTRAINT DF_Usuarios_FC DEFAULT (SYSDATETIME()),
    CONSTRAINT CK_Usuarios_Usuario  CHECK (LEN(Usuario) >= 3 AND Usuario NOT LIKE '% %'),
    CONSTRAINT CK_Usuarios_Intentos CHECK (IntentosFallidos >= 0)
);
GO

IF OBJECT_ID(N'seg.RefreshTokens', N'U') IS NULL
CREATE TABLE seg.RefreshTokens (
    IdToken           BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_RefreshTokens PRIMARY KEY,
    IdUsuario         INT            NOT NULL CONSTRAINT FK_RT_Usuarios REFERENCES seg.Usuarios (IdUsuario),
    TokenHash         CHAR(64)       NOT NULL CONSTRAINT UQ_RT_Hash UNIQUE,
    Expira            DATETIME2(0)   NOT NULL,
    FechaCreacion     DATETIME2(0)   NOT NULL CONSTRAINT DF_RT_FC DEFAULT (SYSUTCDATETIME()),
    CreadoIp          VARCHAR(45)    NULL,
    RevocadoEn        DATETIME2(0)   NULL,
    MotivoRevocacion  VARCHAR(30)    NULL,   -- Logout | Rotado | Reutilizado
    ReemplazadoPor    CHAR(64)       NULL
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_RT_Usuario')
    CREATE INDEX IX_RT_Usuario ON seg.RefreshTokens (IdUsuario, RevocadoEn);
GO

GRANT SELECT, INSERT, UPDATE ON SCHEMA::seg TO rol_lapromesa_app;
GO

PRINT N'[OK] 14 - Autenticación temporal.';
GO

/* ---------- Catálogos para formularios (bodegas y productos activos) ---------- */
CREATE OR ALTER PROCEDURE compras.sp_Catalogo_Bodegas
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdBodega, Codigo, Nombre, Ubicacion FROM inv.Bodegas WHERE Activo = 1 ORDER BY Nombre;
END
GO

CREATE OR ALTER PROCEDURE compras.sp_Catalogo_Productos
    @Buscar NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @b NVARCHAR(110) = NULLIF(LTRIM(RTRIM(@Buscar)), N'');
    SET @b = REPLACE(REPLACE(REPLACE(@b, N'[', N'[[]'), N'%', N'[%]'), N'_', N'[_]');
    SELECT p.IdProducto, p.Codigo, p.Nombre, p.UnidadMedida, p.CostoPromedio, p.StockMinimo,
           ISNULL(e.Existencia, 0) AS Existencia
    FROM inv.Productos AS p
    OUTER APPLY (SELECT SUM(Cantidad) AS Existencia FROM inv.Existencias WHERE IdProducto = p.IdProducto) AS e
    WHERE p.Activo = 1
      AND (@b IS NULL OR p.Codigo LIKE N'%' + @b + N'%' OR p.Nombre LIKE N'%' + @b + N'%')
    ORDER BY p.Nombre;
END
GO
PRINT N'[OK] 14 - Catálogos.';
GO

/* ---------- Procedimientos de autenticación (usados por LaPromesa.Datos.UsuarioDatos) ---------- */
CREATE OR ALTER PROCEDURE seg.sp_Usuario_BuscarPorNombre
    @Usuario VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.IdUsuario, u.Usuario AS NombreUsuario, u.NombreCompleto, u.PasswordHash, r.Nombre AS Rol,
           u.Activo, u.IntentosFallidos, u.BloqueadoHasta
    FROM seg.Usuarios AS u
    INNER JOIN seg.Roles AS r ON r.IdRol = u.IdRol
    WHERE u.Usuario = @Usuario;
END
GO

CREATE OR ALTER PROCEDURE seg.sp_Usuario_BuscarPorId
    @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.IdUsuario, u.Usuario AS NombreUsuario, u.NombreCompleto, u.PasswordHash, r.Nombre AS Rol,
           u.Activo, u.IntentosFallidos, u.BloqueadoHasta
    FROM seg.Usuarios AS u
    INNER JOIN seg.Roles AS r ON r.IdRol = u.IdRol
    WHERE u.IdUsuario = @IdUsuario;
END
GO

CREATE OR ALTER PROCEDURE seg.sp_Usuario_RegistrarAcceso
    @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE seg.Usuarios
       SET IntentosFallidos = 0, BloqueadoHasta = NULL, UltimoAcceso = SYSDATETIME()
     WHERE IdUsuario = @IdUsuario;
END
GO

/* Bloqueo de 15 minutos al quinto intento fallido */
CREATE OR ALTER PROCEDURE seg.sp_Usuario_RegistrarIntentoFallido
    @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE seg.Usuarios
       SET IntentosFallidos = IntentosFallidos + 1,
           BloqueadoHasta   = CASE WHEN IntentosFallidos + 1 >= 5 THEN DATEADD(MINUTE, 15, SYSUTCDATETIME()) END
     WHERE IdUsuario = @IdUsuario;
END
GO

CREATE OR ALTER PROCEDURE seg.sp_Usuario_Contar
AS
BEGIN
    SET NOCOUNT ON;
    SELECT COUNT(*) AS Total FROM seg.Usuarios;
END
GO

CREATE OR ALTER PROCEDURE seg.sp_Usuario_Crear
    @Usuario         VARCHAR(50),
    @NombreCompleto  NVARCHAR(150),
    @PasswordHash    VARCHAR(100),
    @Rol             VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF NOT EXISTS (SELECT 1 FROM seg.Roles WHERE Nombre = @Rol)
        THROW 51060, N'El rol indicado no existe.', 1;
    IF EXISTS (SELECT 1 FROM seg.Usuarios WHERE Usuario = @Usuario)
        THROW 53030, N'El nombre de usuario ya existe.', 1;
    INSERT INTO seg.Usuarios (Usuario, NombreCompleto, PasswordHash, IdRol)
    SELECT @Usuario, @NombreCompleto, @PasswordHash, IdRol FROM seg.Roles WHERE Nombre = @Rol;
END
GO

CREATE OR ALTER PROCEDURE seg.sp_RefreshToken_Guardar
    @IdUsuario  INT,
    @TokenHash  CHAR(64),
    @Expira     DATETIME2(0),
    @CreadoIp   VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO seg.RefreshTokens (IdUsuario, TokenHash, Expira, CreadoIp)
    VALUES (@IdUsuario, @TokenHash, @Expira, @CreadoIp);
END
GO

CREATE OR ALTER PROCEDURE seg.sp_RefreshToken_Buscar
    @TokenHash CHAR(64)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdToken, IdUsuario, Expira, RevocadoEn FROM seg.RefreshTokens WHERE TokenHash = @TokenHash;
END
GO

/* Revoca solo si sigue activo: evita que dos renovaciones simultáneas usen el mismo token */
CREATE OR ALTER PROCEDURE seg.sp_RefreshToken_Revocar
    @TokenHash       CHAR(64),
    @Motivo          VARCHAR(30),
    @ReemplazadoPor  CHAR(64) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE seg.RefreshTokens
       SET RevocadoEn = SYSUTCDATETIME(), MotivoRevocacion = @Motivo, ReemplazadoPor = @ReemplazadoPor
     WHERE TokenHash = @TokenHash AND RevocadoEn IS NULL;
    SELECT @@ROWCOUNT AS Total;
END
GO

CREATE OR ALTER PROCEDURE seg.sp_RefreshToken_RevocarTodos
    @IdUsuario INT,
    @Motivo    VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE seg.RefreshTokens
       SET RevocadoEn = SYSUTCDATETIME(), MotivoRevocacion = @Motivo
     WHERE IdUsuario = @IdUsuario AND RevocadoEn IS NULL;
END
GO

GRANT EXECUTE ON SCHEMA::seg TO rol_lapromesa_app;
GO
PRINT N'[OK] 14 - Procedimientos de autenticación.';
GO
