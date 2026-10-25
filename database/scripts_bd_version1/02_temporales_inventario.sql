/* =========================================================
   La Promesa ERP - 02 Tablas TEMPORALES de inventario
   ---------------------------------------------------------
   Tablas mínimas de inventario para probar el proceso de Compras.
   Al integrar el proyecto se conectan con el módulo de
   Inventarios y se ajustan las referencias.
   ========================================================= */
USE LaPromesaERP;
GO

IF OBJECT_ID(N'dbo.Bodegas') IS NULL
CREATE TABLE dbo.Bodegas (
    IdBodega        INT IDENTITY(1,1) CONSTRAINT PK_Bodegas PRIMARY KEY,
    Nombre          NVARCHAR(100) NOT NULL CONSTRAINT UQ_Bodegas_Nombre UNIQUE,
    Ubicacion       NVARCHAR(200) NULL,
    Activo          BIT NOT NULL CONSTRAINT DF_Bodegas_Activo DEFAULT (1)
);
GO

IF OBJECT_ID(N'dbo.Productos') IS NULL
CREATE TABLE dbo.Productos (
    IdProducto        INT IDENTITY(1,1) CONSTRAINT PK_Productos PRIMARY KEY,
    Codigo            VARCHAR(20)   NOT NULL CONSTRAINT UQ_Productos_Codigo UNIQUE,
    Nombre            NVARCHAR(150) NOT NULL,
    UnidadMedida      NVARCHAR(20)  NOT NULL CONSTRAINT DF_Productos_Unidad DEFAULT (N'Unidad'),
    CostoPromedio     DECIMAL(18,4) NOT NULL CONSTRAINT DF_Productos_Costo DEFAULT (0),
    Activo            BIT NOT NULL CONSTRAINT DF_Productos_Activo DEFAULT (1),
    CONSTRAINT CK_Productos_Costo CHECK (CostoPromedio >= 0)
);
GO

/* Existencia por producto y bodega */
IF OBJECT_ID(N'dbo.Existencias') IS NULL
CREATE TABLE dbo.Existencias (
    IdProducto  INT NOT NULL CONSTRAINT FK_Existencias_Productos REFERENCES dbo.Productos(IdProducto),
    IdBodega    INT NOT NULL CONSTRAINT FK_Existencias_Bodegas   REFERENCES dbo.Bodegas(IdBodega),
    Cantidad    DECIMAL(18,2) NOT NULL CONSTRAINT DF_Existencias_Cantidad DEFAULT (0),
    CONSTRAINT PK_Existencias PRIMARY KEY (IdProducto, IdBodega),
    CONSTRAINT CK_Existencias_Cantidad CHECK (Cantidad >= 0)
);
GO

/* Kardex: cada entrada/salida de inventario con su documento de origen */
IF OBJECT_ID(N'dbo.MovimientosInventario') IS NULL
CREATE TABLE dbo.MovimientosInventario (
    IdMovimiento    BIGINT IDENTITY(1,1) CONSTRAINT PK_MovimientosInventario PRIMARY KEY,
    IdProducto      INT NOT NULL CONSTRAINT FK_MovInv_Productos REFERENCES dbo.Productos(IdProducto),
    IdBodega        INT NOT NULL CONSTRAINT FK_MovInv_Bodegas   REFERENCES dbo.Bodegas(IdBodega),
    Tipo            VARCHAR(10)   NOT NULL,          -- ENTRADA / SALIDA
    Cantidad        DECIMAL(18,2) NOT NULL,
    CostoUnitario   DECIMAL(18,4) NOT NULL,
    DocumentoOrigen VARCHAR(30)   NOT NULL,          -- ej. RECEPCION
    IdDocumento     INT           NOT NULL,
    Fecha           DATETIME2(0)  NOT NULL CONSTRAINT DF_MovInv_Fecha DEFAULT (SYSDATETIME()),
    Usuario         NVARCHAR(100) NOT NULL,
    CONSTRAINT CK_MovInv_Tipo CHECK (Tipo IN ('ENTRADA','SALIDA')),
    CONSTRAINT CK_MovInv_Cantidad CHECK (Cantidad > 0)
);
GO
