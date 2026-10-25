/* =====================================================================
   LA PROMESA ERP  |  02 - Esquemas, parámetros y auditoría
   ---------------------------------------------------------------------
   Esquemas:
     cfg     -> parámetros del sistema (IVA, tolerancias, límites)
     inv     -> inventario base para el proceso de compras
     compras -> Proveedores, Órdenes de compra, Recepciones,
                Cuentas por pagar y Pagos
     rpt     -> procedimientos de reportes
     aud     -> bitácora de cambios y registro de errores
   Los esquemas separan cada área y evitan choques de nombres al
   integrar con los demás módulos del ERP.
   ===================================================================== */
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
USE LaPromesaERP;
GO

IF SCHEMA_ID(N'cfg')     IS NULL EXEC (N'CREATE SCHEMA cfg AUTHORIZATION dbo;');
IF SCHEMA_ID(N'inv')     IS NULL EXEC (N'CREATE SCHEMA inv AUTHORIZATION dbo;');
IF SCHEMA_ID(N'compras') IS NULL EXEC (N'CREATE SCHEMA compras AUTHORIZATION dbo;');
IF SCHEMA_ID(N'rpt')     IS NULL EXEC (N'CREATE SCHEMA rpt AUTHORIZATION dbo;');
IF SCHEMA_ID(N'aud')     IS NULL EXEC (N'CREATE SCHEMA aud AUTHORIZATION dbo;');
GO

/* ---------------------------------------------------------------------
   cfg.Parametros: valores de negocio configurables sin tocar código
   --------------------------------------------------------------------- */
IF OBJECT_ID(N'cfg.Parametros', N'U') IS NULL
CREATE TABLE cfg.Parametros (
    Clave              VARCHAR(50)    NOT NULL CONSTRAINT PK_Parametros PRIMARY KEY,
    Valor              NVARCHAR(200)  NOT NULL,
    Descripcion        NVARCHAR(250)  NULL,
    FechaModificacion  DATETIME2(0)   NOT NULL CONSTRAINT DF_Parametros_Fecha   DEFAULT (SYSDATETIME()),
    ModificadoPor      NVARCHAR(100)  NOT NULL CONSTRAINT DF_Parametros_Usuario DEFAULT (N'sistema')
);
GO

MERGE cfg.Parametros AS t
USING (VALUES
    ('TASA_IVA',                N'0.12', N'Tasa de IVA aplicada a las compras (Guatemala 12 %).'),
    ('MONEDA',                  N'GTQ',  N'Moneda del sistema (quetzales).'),
    ('DIAS_CREDITO_MAX',        N'180',  N'Máximo de días de crédito permitidos a un proveedor.'),
    ('TOLERANCIA_DIAS_ENTREGA', N'0',    N'Días de tolerancia para considerar una entrega "a tiempo" (RQ27).'),
    ('OC_APROBADOR_DISTINTO',   N'1',    N'1 = quien crea la orden de compra no puede aprobarla (segregación de funciones).'),
    ('OC_MAX_LINEAS',           N'100',  N'Máximo de líneas por orden de compra.'),
    ('PAGO_MAX_INTENTOS',       N'3',    N'Intentos máximos contra la API bancaria antes de marcar el pago como rechazado.')
) AS s (Clave, Valor, Descripcion)
ON t.Clave = s.Clave
WHEN NOT MATCHED THEN
    INSERT (Clave, Valor, Descripcion) VALUES (s.Clave, s.Valor, s.Descripcion);
GO

/* ---------------------------------------------------------------------
   aud.Bitacora: quién cambió qué, cuándo, con valores antes/después.
   La llenan los triggers de auditoría. Es de solo inserción.
   --------------------------------------------------------------------- */
IF OBJECT_ID(N'aud.Bitacora', N'U') IS NULL
CREATE TABLE aud.Bitacora (
    IdBitacora       BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Bitacora PRIMARY KEY,
    Tabla            NVARCHAR(128)  NOT NULL,
    IdRegistro       NVARCHAR(50)   NOT NULL,
    Operacion        VARCHAR(10)    NOT NULL,
    Usuario          NVARCHAR(128)  NOT NULL,
    Fecha            DATETIME2(3)   NOT NULL CONSTRAINT DF_Bitacora_Fecha DEFAULT (SYSDATETIME()),
    DatosAnteriores  NVARCHAR(MAX)  NULL,
    DatosNuevos      NVARCHAR(MAX)  NULL,
    Equipo           NVARCHAR(128)  NULL CONSTRAINT DF_Bitacora_Equipo DEFAULT (HOST_NAME()),
    Aplicacion       NVARCHAR(128)  NULL CONSTRAINT DF_Bitacora_App    DEFAULT (APP_NAME()),
    CONSTRAINT CK_Bitacora_Operacion CHECK (Operacion IN ('INSERT', 'UPDATE', 'DELETE')),
    CONSTRAINT CK_Bitacora_JsonAnt   CHECK (DatosAnteriores IS NULL OR ISJSON(DatosAnteriores) = 1),
    CONSTRAINT CK_Bitacora_JsonNuevo CHECK (DatosNuevos     IS NULL OR ISJSON(DatosNuevos)     = 1)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Bitacora_Tabla_Registro')
    CREATE INDEX IX_Bitacora_Tabla_Registro ON aud.Bitacora (Tabla, IdRegistro, Fecha);
GO

/* ---------------------------------------------------------------------
   aud.ErroresBD: todo error capturado en los BEGIN CATCH de los
   procedimientos queda registrado aquí (diagnóstico y evidencia).
   --------------------------------------------------------------------- */
IF OBJECT_ID(N'aud.ErroresBD', N'U') IS NULL
CREATE TABLE aud.ErroresBD (
    IdError        BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ErroresBD PRIMARY KEY,
    Fecha          DATETIME2(3)   NOT NULL CONSTRAINT DF_ErroresBD_Fecha DEFAULT (SYSDATETIME()),
    Procedimiento  NVARCHAR(256)  NULL,
    Numero         INT            NULL,
    Severidad      INT            NULL,
    Estado         INT            NULL,
    Linea          INT            NULL,
    Mensaje        NVARCHAR(4000) NULL,
    EsDeNegocio    AS (CAST(CASE WHEN Numero >= 50000 THEN 1 ELSE 0 END AS BIT)),
    Usuario        NVARCHAR(128)  NULL,
    Parametros     NVARCHAR(MAX)  NULL
);
GO

/* ---------------------------------------------------------------------
   aud.sp_RegistrarError: se llama desde cada BEGIN CATCH, DESPUÉS del
   ROLLBACK, para que el registro del error no se pierda.
   Nunca lanza error propio (no debe ocultar el error original).
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE aud.sp_RegistrarError
    @Procedimiento NVARCHAR(256) = NULL,
    @Parametros    NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        INSERT INTO aud.ErroresBD (Procedimiento, Numero, Severidad, Estado, Linea, Mensaje, Usuario, Parametros)
        VALUES (
            COALESCE(@Procedimiento, ERROR_PROCEDURE()),
            ERROR_NUMBER(), ERROR_SEVERITY(), ERROR_STATE(), ERROR_LINE(), ERROR_MESSAGE(),
            COALESCE(CONVERT(NVARCHAR(128), SESSION_CONTEXT(N'usuario')), ORIGINAL_LOGIN()),
            @Parametros
        );
    END TRY
    BEGIN CATCH
        -- Silencioso a propósito: el error importante es el original.
        RETURN;
    END CATCH
END
GO

PRINT N'[OK] 02 - Esquemas, parámetros y auditoría.';
GO
