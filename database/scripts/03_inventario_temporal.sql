/* =====================================================================
   LA PROMESA ERP  |  03 - Inventario (TEMPORAL)
   ---------------------------------------------------------------------
   IMPORTANTE: estas tablas pertenecen al módulo de INVENTARIOS
   (compañero Fernando). Se crean en el esquema "inv" SOLO para poder
   probar el proceso de Compras de forma independiente:
       Recepción de compra -> entrada a bodega -> existencias + kardex
   Al integrar, se reemplazan por las tablas reales de Fernando y se
   ajusta únicamente el bloque "INVENTARIO" de compras.sp_Recepcion_Registrar.
   ===================================================================== */
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
USE LaPromesaERP;
GO

IF OBJECT_ID(N'inv.Bodegas', N'U') IS NULL
CREATE TABLE inv.Bodegas (
    IdBodega       INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Bodegas PRIMARY KEY,
    Codigo         VARCHAR(10)    NOT NULL CONSTRAINT UQ_Bodegas_Codigo UNIQUE,
    Nombre         NVARCHAR(100)  NOT NULL CONSTRAINT UQ_Bodegas_Nombre UNIQUE,
    Ubicacion      NVARCHAR(200)  NULL,
    Activo         BIT            NOT NULL CONSTRAINT DF_Bodegas_Activo DEFAULT (1),
    FechaCreacion  DATETIME2(0)   NOT NULL CONSTRAINT DF_Bodegas_FC     DEFAULT (SYSDATETIME())
);
GO

IF OBJECT_ID(N'inv.Productos', N'U') IS NULL
CREATE TABLE inv.Productos (
    IdProducto     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Productos PRIMARY KEY,
    Codigo         VARCHAR(20)    NOT NULL CONSTRAINT UQ_Productos_Codigo UNIQUE,
    Nombre         NVARCHAR(150)  NOT NULL,
    UnidadMedida   NVARCHAR(20)   NOT NULL CONSTRAINT DF_Productos_Unidad DEFAULT (N'Unidad'),
    CostoPromedio  DECIMAL(18,4)  NOT NULL CONSTRAINT DF_Productos_Costo  DEFAULT (0),
    StockMinimo    DECIMAL(18,2)  NOT NULL CONSTRAINT DF_Productos_Minimo DEFAULT (0),
    Activo         BIT            NOT NULL CONSTRAINT DF_Productos_Activo DEFAULT (1),
    FechaCreacion  DATETIME2(0)   NOT NULL CONSTRAINT DF_Productos_FC     DEFAULT (SYSDATETIME()),
    CONSTRAINT CK_Productos_Costo  CHECK (CostoPromedio >= 0),
    CONSTRAINT CK_Productos_Minimo CHECK (StockMinimo >= 0)
);
GO

/* Existencia actual por producto y bodega */
IF OBJECT_ID(N'inv.Existencias', N'U') IS NULL
CREATE TABLE inv.Existencias (
    IdProducto          INT           NOT NULL CONSTRAINT FK_Existencias_Productos REFERENCES inv.Productos (IdProducto),
    IdBodega            INT           NOT NULL CONSTRAINT FK_Existencias_Bodegas   REFERENCES inv.Bodegas (IdBodega),
    Cantidad            DECIMAL(18,2) NOT NULL CONSTRAINT DF_Existencias_Cantidad DEFAULT (0),
    FechaActualizacion  DATETIME2(0)  NOT NULL CONSTRAINT DF_Existencias_Fecha    DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_Existencias PRIMARY KEY (IdProducto, IdBodega),
    CONSTRAINT CK_Existencias_Cantidad CHECK (Cantidad >= 0)
);
GO

/* Kardex: toda entrada/salida con su documento de origen (inmutable) */
IF OBJECT_ID(N'inv.MovimientosInventario', N'U') IS NULL
CREATE TABLE inv.MovimientosInventario (
    IdMovimiento     BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_MovimientosInventario PRIMARY KEY,
    IdProducto       INT            NOT NULL CONSTRAINT FK_MovInv_Productos REFERENCES inv.Productos (IdProducto),
    IdBodega         INT            NOT NULL CONSTRAINT FK_MovInv_Bodegas   REFERENCES inv.Bodegas (IdBodega),
    Tipo             VARCHAR(10)    NOT NULL,
    Cantidad         DECIMAL(18,2)  NOT NULL,
    CostoUnitario    DECIMAL(18,4)  NOT NULL,
    DocumentoOrigen  VARCHAR(30)    NOT NULL,
    IdDocumento      INT            NOT NULL,
    Fecha            DATETIME2(0)   NOT NULL CONSTRAINT DF_MovInv_Fecha DEFAULT (SYSDATETIME()),
    Usuario          NVARCHAR(100)  NOT NULL,
    CONSTRAINT CK_MovInv_Tipo     CHECK (Tipo IN ('ENTRADA', 'SALIDA')),
    CONSTRAINT CK_MovInv_Cantidad CHECK (Cantidad > 0),
    CONSTRAINT CK_MovInv_Costo    CHECK (CostoUnitario >= 0)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_MovInv_Producto_Fecha')
    CREATE INDEX IX_MovInv_Producto_Fecha ON inv.MovimientosInventario (IdProducto, Fecha);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_MovInv_Documento')
    CREATE INDEX IX_MovInv_Documento ON inv.MovimientosInventario (DocumentoOrigen, IdDocumento);
GO

PRINT N'[OK] 03 - Inventario temporal.';
GO
