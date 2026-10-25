/* =========================================================
   La Promesa ERP - 03 Módulos: PROVEEDORES y COMPRAS
   Incluye: proveedores, órdenes de compra, recepciones,
            cuentas por pagar y pagos a proveedores.
   Reglas: eliminaciones como inactivación/anulación con
           trazabilidad (fecha, usuario, motivo).
   ========================================================= */
USE LaPromesaERP;
GO

/* ---------- PROVEEDORES (RQ25) ---------- */
IF OBJECT_ID(N'dbo.Proveedores') IS NULL
CREATE TABLE dbo.Proveedores (
    IdProveedor         INT IDENTITY(1,1) CONSTRAINT PK_Proveedores PRIMARY KEY,
    Codigo              VARCHAR(10)   NOT NULL CONSTRAINT UQ_Proveedores_Codigo UNIQUE,  -- PR001
    Nombre              NVARCHAR(150) NOT NULL,
    Nit                 VARCHAR(15)   NOT NULL CONSTRAINT UQ_Proveedores_Nit UNIQUE,
    Contacto            NVARCHAR(100) NULL,
    Telefono            VARCHAR(20)   NULL,
    Email               NVARCHAR(150) NULL,
    Direccion           NVARCHAR(200) NULL,
    Categoria           NVARCHAR(50)  NULL,
    TipoPago            VARCHAR(10)   NOT NULL,                       -- Contado / Credito
    DiasCredito         INT           NOT NULL CONSTRAINT DF_Proveedores_Dias DEFAULT (0),
    Estado              VARCHAR(10)   NOT NULL CONSTRAINT DF_Proveedores_Estado DEFAULT ('Activo'),
    FechaCreacion       DATETIME2(0)  NOT NULL CONSTRAINT DF_Proveedores_FC DEFAULT (SYSDATETIME()),
    CreadoPor           NVARCHAR(100) NOT NULL,
    FechaModificacion   DATETIME2(0)  NULL,
    ModificadoPor       NVARCHAR(100) NULL,
    FechaInactivacion   DATETIME2(0)  NULL,
    InactivadoPor       NVARCHAR(100) NULL,
    MotivoInactivacion  NVARCHAR(250) NULL,
    CONSTRAINT CK_Proveedores_TipoPago CHECK (TipoPago IN ('Contado','Credito')),
    CONSTRAINT CK_Proveedores_Estado   CHECK (Estado IN ('Activo','Inactivo')),
    CONSTRAINT CK_Proveedores_Dias     CHECK (
        (TipoPago = 'Contado' AND DiasCredito = 0) OR
        (TipoPago = 'Credito' AND DiasCredito BETWEEN 1 AND 180))
);
GO

/* ---------- ÓRDENES DE COMPRA (RQ04, RQ27) ---------- */
IF OBJECT_ID(N'dbo.OrdenesCompra') IS NULL
CREATE TABLE dbo.OrdenesCompra (
    IdOrdenCompra       INT IDENTITY(1,1) CONSTRAINT PK_OrdenesCompra PRIMARY KEY,
    Numero              VARCHAR(15)   NOT NULL CONSTRAINT UQ_OrdenesCompra_Numero UNIQUE, -- OC-000001
    IdProveedor         INT           NOT NULL CONSTRAINT FK_OC_Proveedores REFERENCES dbo.Proveedores(IdProveedor),
    IdBodega            INT           NOT NULL CONSTRAINT FK_OC_Bodegas     REFERENCES dbo.Bodegas(IdBodega),
    FechaOrden          DATE          NOT NULL,
    FechaEsperada       DATE          NOT NULL,       -- día esperado de llegada (RQ27)
    TipoPago            VARCHAR(10)   NOT NULL,       -- copiado del proveedor al crear
    DiasCredito         INT           NOT NULL,
    Observaciones       NVARCHAR(300) NULL,
    Subtotal            DECIMAL(18,2) NOT NULL CONSTRAINT DF_OC_Subtotal DEFAULT (0),
    Total               DECIMAL(18,2) NOT NULL CONSTRAINT DF_OC_Total    DEFAULT (0),
    Estado              VARCHAR(10)   NOT NULL CONSTRAINT DF_OC_Estado   DEFAULT ('Pendiente'),
    FechaCreacion       DATETIME2(0)  NOT NULL CONSTRAINT DF_OC_FC DEFAULT (SYSDATETIME()),
    CreadoPor           NVARCHAR(100) NOT NULL,
    FechaModificacion   DATETIME2(0)  NULL,
    ModificadoPor       NVARCHAR(100) NULL,
    FechaAnulacion      DATETIME2(0)  NULL,
    AnuladoPor          NVARCHAR(100) NULL,
    MotivoAnulacion     NVARCHAR(250) NULL,
    CONSTRAINT CK_OC_Estado   CHECK (Estado IN ('Pendiente','Parcial','Recibida','Anulada')),
    CONSTRAINT CK_OC_Fechas   CHECK (FechaEsperada >= FechaOrden),
    CONSTRAINT CK_OC_TipoPago CHECK (TipoPago IN ('Contado','Credito')),
    CONSTRAINT CK_OC_Montos   CHECK (Subtotal >= 0 AND Total >= 0)
);
GO

IF OBJECT_ID(N'dbo.OrdenesCompraDetalle') IS NULL
CREATE TABLE dbo.OrdenesCompraDetalle (
    IdDetalle           INT IDENTITY(1,1) CONSTRAINT PK_OrdenesCompraDetalle PRIMARY KEY,
    IdOrdenCompra       INT           NOT NULL CONSTRAINT FK_OCD_OC REFERENCES dbo.OrdenesCompra(IdOrdenCompra),
    IdProducto          INT           NOT NULL CONSTRAINT FK_OCD_Productos REFERENCES dbo.Productos(IdProducto),
    CantidadPedida      DECIMAL(18,2) NOT NULL,
    CantidadRecibida    DECIMAL(18,2) NOT NULL CONSTRAINT DF_OCD_Recibida DEFAULT (0),
    CostoUnitario       DECIMAL(18,4) NOT NULL,
    Subtotal            AS CAST(CantidadPedida * CostoUnitario AS DECIMAL(18,2)) PERSISTED,
    CONSTRAINT UQ_OCD_Producto UNIQUE (IdOrdenCompra, IdProducto),
    CONSTRAINT CK_OCD_Cantidades CHECK (CantidadPedida > 0 AND CantidadRecibida >= 0 AND CantidadRecibida <= CantidadPedida),
    CONSTRAINT CK_OCD_Costo CHECK (CostoUnitario > 0)
);
GO

/* ---------- RECEPCIONES DE MERCADERÍA ---------- */
IF OBJECT_ID(N'dbo.Recepciones') IS NULL
CREATE TABLE dbo.Recepciones (
    IdRecepcion         INT IDENTITY(1,1) CONSTRAINT PK_Recepciones PRIMARY KEY,
    Numero              VARCHAR(15)   NOT NULL CONSTRAINT UQ_Recepciones_Numero UNIQUE, -- RC-000001
    IdOrdenCompra       INT           NOT NULL CONSTRAINT FK_Rec_OC REFERENCES dbo.OrdenesCompra(IdOrdenCompra),
    FechaRecepcion      DATE          NOT NULL,
    NumeroFacturaProveedor VARCHAR(30) NOT NULL,
    Cumplimiento        VARCHAR(10)   NOT NULL,       -- ATiempo / Retraso / Anticipada (RQ27)
    DiasDiferencia      INT           NOT NULL,       -- FechaRecepcion - FechaEsperada
    Total               DECIMAL(18,2) NOT NULL,
    Observaciones       NVARCHAR(300) NULL,
    FechaCreacion       DATETIME2(0)  NOT NULL CONSTRAINT DF_Rec_FC DEFAULT (SYSDATETIME()),
    RecibidoPor         NVARCHAR(100) NOT NULL,
    CONSTRAINT CK_Rec_Cumplimiento CHECK (Cumplimiento IN ('ATiempo','Retraso','Anticipada')),
    CONSTRAINT CK_Rec_Total CHECK (Total > 0)
);
GO

IF OBJECT_ID(N'dbo.RecepcionesDetalle') IS NULL
CREATE TABLE dbo.RecepcionesDetalle (
    IdRecepcionDetalle  INT IDENTITY(1,1) CONSTRAINT PK_RecepcionesDetalle PRIMARY KEY,
    IdRecepcion         INT           NOT NULL CONSTRAINT FK_RecD_Rec REFERENCES dbo.Recepciones(IdRecepcion),
    IdDetalleOrden      INT           NOT NULL CONSTRAINT FK_RecD_OCD REFERENCES dbo.OrdenesCompraDetalle(IdDetalle),
    CantidadRecibida    DECIMAL(18,2) NOT NULL,
    CostoUnitario       DECIMAL(18,4) NOT NULL,
    CONSTRAINT CK_RecD_Cantidad CHECK (CantidadRecibida > 0)
);
GO

/* ---------- CUENTAS POR PAGAR ---------- */
IF OBJECT_ID(N'dbo.CuentasPorPagar') IS NULL
CREATE TABLE dbo.CuentasPorPagar (
    IdCuentaPagar       INT IDENTITY(1,1) CONSTRAINT PK_CuentasPorPagar PRIMARY KEY,
    IdRecepcion         INT           NOT NULL CONSTRAINT UQ_CxP_Recepcion UNIQUE
                                      CONSTRAINT FK_CxP_Rec REFERENCES dbo.Recepciones(IdRecepcion),
    IdProveedor         INT           NOT NULL CONSTRAINT FK_CxP_Proveedores REFERENCES dbo.Proveedores(IdProveedor),
    FechaEmision        DATE          NOT NULL,
    FechaVencimiento    DATE          NOT NULL,       -- FechaEmision + DiasCredito
    Monto               DECIMAL(18,2) NOT NULL,
    Saldo               DECIMAL(18,2) NOT NULL,
    Estado              VARCHAR(10)   NOT NULL CONSTRAINT DF_CxP_Estado DEFAULT ('Pendiente'),
    CONSTRAINT CK_CxP_Estado CHECK (Estado IN ('Pendiente','Parcial','Pagada')),
    CONSTRAINT CK_CxP_Montos CHECK (Monto > 0 AND Saldo >= 0 AND Saldo <= Monto),
    CONSTRAINT CK_CxP_Fechas CHECK (FechaVencimiento >= FechaEmision)
);
GO

/* ---------- PAGOS A PROVEEDORES (API externa de pagos bancarios) ---------- */
IF OBJECT_ID(N'dbo.PagosProveedor') IS NULL
CREATE TABLE dbo.PagosProveedor (
    IdPago              INT IDENTITY(1,1) CONSTRAINT PK_PagosProveedor PRIMARY KEY,
    IdCuentaPagar       INT           NOT NULL CONSTRAINT FK_Pago_CxP REFERENCES dbo.CuentasPorPagar(IdCuentaPagar),
    FechaPago           DATETIME2(0)  NOT NULL CONSTRAINT DF_Pago_Fecha DEFAULT (SYSDATETIME()),
    Monto               DECIMAL(18,2) NOT NULL,
    Metodo              VARCHAR(15)   NOT NULL,       -- Transferencia / Cheque / Efectivo
    Banco               NVARCHAR(60)  NULL,
    ReferenciaBanco     VARCHAR(50)   NULL,           -- autorización devuelta por la API bancaria
    EstadoBanco         VARCHAR(12)   NOT NULL,       -- Aprobado / Rechazado / NoAplica
    MensajeBanco        NVARCHAR(250) NULL,
    RegistradoPor       NVARCHAR(100) NOT NULL,
    CONSTRAINT CK_Pago_Monto  CHECK (Monto > 0),
    CONSTRAINT CK_Pago_Metodo CHECK (Metodo IN ('Transferencia','Cheque','Efectivo')),
    CONSTRAINT CK_Pago_Estado CHECK (EstadoBanco IN ('Aprobado','Rechazado','NoAplica'))
);
GO

/* Índices para búsquedas y reportes */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Proveedores_Nombre')
    CREATE INDEX IX_Proveedores_Nombre ON dbo.Proveedores(Nombre);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_OC_Proveedor_Fecha')
    CREATE INDEX IX_OC_Proveedor_Fecha ON dbo.OrdenesCompra(IdProveedor, FechaOrden);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_OC_Estado_FechaEsperada')
    CREATE INDEX IX_OC_Estado_FechaEsperada ON dbo.OrdenesCompra(Estado, FechaEsperada);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_CxP_Estado_Vencimiento')
    CREATE INDEX IX_CxP_Estado_Vencimiento ON dbo.CuentasPorPagar(Estado, FechaVencimiento);
GO
