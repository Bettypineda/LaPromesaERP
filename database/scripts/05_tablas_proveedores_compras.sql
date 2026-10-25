/* =====================================================================
   LA PROMESA ERP  |  05 - Tablas de PROVEEDORES y COMPRAS (Sara)
   ---------------------------------------------------------------------
   Proceso integrado:
     Orden de compra (Pendiente) -> Aprobación -> Recepción parcial/total
     -> Entrada a inventario -> Cuenta por pagar -> Pago (API bancaria)
   Principios:
     - Nada se elimina físicamente: proveedores se INACTIVAN y órdenes
       se ANULAN, siempre con fecha, usuario y motivo.
     - La recepción (nota de compra) es definitiva: no se modifica.
     - ROWVERSION para control de concurrencia optimista.
     - CHECK, UNIQUE y FOREIGN KEY protegen los datos aunque alguien
       escriba directo en la tabla, sin pasar por la API.
   ===================================================================== */
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
USE LaPromesaERP;
GO

/* ====================== CATEGORÍAS DE PROVEEDOR ====================== */
IF OBJECT_ID(N'compras.CategoriasProveedor', N'U') IS NULL
CREATE TABLE compras.CategoriasProveedor (
    IdCategoria    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_CategoriasProveedor PRIMARY KEY,
    Nombre         NVARCHAR(50)   NOT NULL CONSTRAINT UQ_CategoriasProveedor_Nombre UNIQUE,
    Descripcion    NVARCHAR(200)  NULL,
    Activo         BIT            NOT NULL CONSTRAINT DF_CatProv_Activo DEFAULT (1),
    FechaCreacion  DATETIME2(0)   NOT NULL CONSTRAINT DF_CatProv_FC     DEFAULT (SYSDATETIME()),
    CreadoPor      NVARCHAR(100)  NOT NULL
);
GO

/* ============================ PROVEEDORES (RQ25) ============================ */
IF OBJECT_ID(N'compras.Proveedores', N'U') IS NULL
CREATE TABLE compras.Proveedores (
    IdProveedor         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Proveedores PRIMARY KEY,
    Codigo              VARCHAR(10)    NOT NULL CONSTRAINT UQ_Proveedores_Codigo UNIQUE,
    Nombre              NVARCHAR(150)  NOT NULL,
    Nit                 VARCHAR(15)    NOT NULL CONSTRAINT UQ_Proveedores_Nit UNIQUE,
    IdCategoria         INT            NOT NULL CONSTRAINT FK_Proveedores_Categoria REFERENCES compras.CategoriasProveedor (IdCategoria),
    Contacto            NVARCHAR(100)  NULL,
    Telefono            VARCHAR(9)     NULL,
    Email               NVARCHAR(150)  NULL,
    Direccion           NVARCHAR(200)  NULL,
    Departamento        NVARCHAR(50)   NULL,
    TipoPago            VARCHAR(10)    NOT NULL,
    DiasCredito         INT            NOT NULL CONSTRAINT DF_Proveedores_Dias   DEFAULT (0),
    LimiteCredito       DECIMAL(18,2)  NOT NULL CONSTRAINT DF_Proveedores_Limite DEFAULT (0),
    Banco               NVARCHAR(60)   NULL,
    NumeroCuenta        VARCHAR(30)    NULL,
    Estado              VARCHAR(10)    NOT NULL CONSTRAINT DF_Proveedores_Estado DEFAULT ('Activo'),
    FechaCreacion       DATETIME2(0)   NOT NULL CONSTRAINT DF_Proveedores_FC     DEFAULT (SYSDATETIME()),
    CreadoPor           NVARCHAR(100)  NOT NULL,
    FechaModificacion   DATETIME2(0)   NULL,
    ModificadoPor       NVARCHAR(100)  NULL,
    FechaInactivacion   DATETIME2(0)   NULL,
    InactivadoPor       NVARCHAR(100)  NULL,
    MotivoInactivacion  NVARCHAR(250)  NULL,
    RowVersion          ROWVERSION     NOT NULL,
    CONSTRAINT CK_Proveedores_Nit       CHECK (compras.fn_NitValido(Nit) = 1),
    CONSTRAINT CK_Proveedores_Nombre    CHECK (LEN(LTRIM(RTRIM(Nombre))) >= 3),
    CONSTRAINT CK_Proveedores_Telefono  CHECK (Telefono IS NULL OR Telefono LIKE '[2-7][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]'),
    CONSTRAINT CK_Proveedores_Email     CHECK (Email IS NULL OR (Email LIKE '%_@_%._%' AND Email NOT LIKE '% %')),
    CONSTRAINT CK_Proveedores_TipoPago  CHECK (TipoPago IN ('Contado', 'Credito')),
    CONSTRAINT CK_Proveedores_Dias      CHECK ((TipoPago = 'Contado' AND DiasCredito = 0)
                                            OR (TipoPago = 'Credito' AND DiasCredito BETWEEN 1 AND 180)),
    CONSTRAINT CK_Proveedores_Limite    CHECK (LimiteCredito >= 0 AND (TipoPago = 'Credito' OR LimiteCredito = 0)),
    CONSTRAINT CK_Proveedores_Estado    CHECK (Estado IN ('Activo', 'Inactivo')),
    CONSTRAINT CK_Proveedores_Inactivo  CHECK (Estado = 'Activo'
                                            OR (FechaInactivacion IS NOT NULL AND InactivadoPor IS NOT NULL AND MotivoInactivacion IS NOT NULL))
);
GO

/* ======================= ÓRDENES DE COMPRA (RQ04, RQ27) ======================= */
IF OBJECT_ID(N'compras.OrdenesCompra', N'U') IS NULL
CREATE TABLE compras.OrdenesCompra (
    IdOrdenCompra      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_OrdenesCompra PRIMARY KEY,
    Numero             VARCHAR(15)    NOT NULL CONSTRAINT UQ_OrdenesCompra_Numero UNIQUE,
    IdProveedor        INT            NOT NULL CONSTRAINT FK_OC_Proveedores REFERENCES compras.Proveedores (IdProveedor),
    IdBodega           INT            NOT NULL CONSTRAINT FK_OC_Bodegas     REFERENCES inv.Bodegas (IdBodega),
    FechaOrden         DATE           NOT NULL,
    FechaEsperada      DATE           NOT NULL,
    TipoPago           VARCHAR(10)    NOT NULL,   -- copia del proveedor al crear (historia fiel)
    DiasCredito        INT            NOT NULL,
    Observaciones      NVARCHAR(300)  NULL,
    TasaIva            DECIMAL(5,4)   NOT NULL,
    Subtotal           DECIMAL(18,2)  NOT NULL CONSTRAINT DF_OC_Subtotal DEFAULT (0),
    Iva                DECIMAL(18,2)  NOT NULL CONSTRAINT DF_OC_Iva      DEFAULT (0),
    Total              DECIMAL(18,2)  NOT NULL CONSTRAINT DF_OC_Total    DEFAULT (0),
    Estado             VARCHAR(10)    NOT NULL CONSTRAINT DF_OC_Estado   DEFAULT ('Pendiente'),
    FechaCreacion      DATETIME2(0)   NOT NULL CONSTRAINT DF_OC_FC       DEFAULT (SYSDATETIME()),
    CreadoPor          NVARCHAR(100)  NOT NULL,
    FechaModificacion  DATETIME2(0)   NULL,
    ModificadoPor      NVARCHAR(100)  NULL,
    FechaAprobacion    DATETIME2(0)   NULL,
    AprobadoPor        NVARCHAR(100)  NULL,
    FechaAnulacion     DATETIME2(0)   NULL,
    AnuladoPor         NVARCHAR(100)  NULL,
    MotivoAnulacion    NVARCHAR(250)  NULL,
    RowVersion         ROWVERSION     NOT NULL,
    CONSTRAINT CK_OC_Estado     CHECK (Estado IN ('Pendiente', 'Aprobada', 'Parcial', 'Recibida', 'Anulada')),
    CONSTRAINT CK_OC_Fechas     CHECK (FechaEsperada >= FechaOrden),
    CONSTRAINT CK_OC_TipoPago   CHECK (TipoPago IN ('Contado', 'Credito')),
    CONSTRAINT CK_OC_Dias       CHECK (DiasCredito >= 0),
    CONSTRAINT CK_OC_Tasa       CHECK (TasaIva >= 0 AND TasaIva < 1),
    CONSTRAINT CK_OC_Montos     CHECK (Subtotal >= 0 AND Iva >= 0 AND Total = Subtotal + Iva),
    CONSTRAINT CK_OC_Aprobacion CHECK (Estado NOT IN ('Aprobada', 'Parcial', 'Recibida')
                                    OR (AprobadoPor IS NOT NULL AND FechaAprobacion IS NOT NULL)),
    CONSTRAINT CK_OC_Anulacion  CHECK (Estado <> 'Anulada'
                                    OR (FechaAnulacion IS NOT NULL AND AnuladoPor IS NOT NULL AND MotivoAnulacion IS NOT NULL))
);
GO

IF OBJECT_ID(N'compras.OrdenesCompraDetalle', N'U') IS NULL
CREATE TABLE compras.OrdenesCompraDetalle (
    IdDetalle         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_OrdenesCompraDetalle PRIMARY KEY,
    IdOrdenCompra     INT            NOT NULL CONSTRAINT FK_OCD_OC        REFERENCES compras.OrdenesCompra (IdOrdenCompra),
    IdProducto        INT            NOT NULL CONSTRAINT FK_OCD_Productos REFERENCES inv.Productos (IdProducto),
    CantidadPedida    DECIMAL(18,2)  NOT NULL,
    CantidadRecibida  DECIMAL(18,2)  NOT NULL CONSTRAINT DF_OCD_Recibida DEFAULT (0),
    CostoUnitario     DECIMAL(18,4)  NOT NULL,
    Subtotal          AS CAST(CantidadPedida * CostoUnitario AS DECIMAL(18,2)) PERSISTED,
    CONSTRAINT UQ_OCD_Producto   UNIQUE (IdOrdenCompra, IdProducto),
    CONSTRAINT CK_OCD_Cantidades CHECK (CantidadPedida > 0 AND CantidadRecibida >= 0 AND CantidadRecibida <= CantidadPedida),
    CONSTRAINT CK_OCD_Costo      CHECK (CostoUnitario > 0)
);
GO

/* Historial de estados de cada orden (trazabilidad del proceso) */
IF OBJECT_ID(N'compras.OrdenesCompraHistorial', N'U') IS NULL
CREATE TABLE compras.OrdenesCompraHistorial (
    IdHistorial     BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_OCHistorial PRIMARY KEY,
    IdOrdenCompra   INT            NOT NULL CONSTRAINT FK_OCH_OC REFERENCES compras.OrdenesCompra (IdOrdenCompra),
    EstadoAnterior  VARCHAR(10)    NULL,
    EstadoNuevo     VARCHAR(10)    NOT NULL,
    Fecha           DATETIME2(0)   NOT NULL CONSTRAINT DF_OCH_Fecha DEFAULT (SYSDATETIME()),
    Usuario         NVARCHAR(128)  NOT NULL,
    Comentario      NVARCHAR(250)  NULL
);
GO

/* ================== RECEPCIONES (NOTA DE COMPRA, DEFINITIVA) ================== */
IF OBJECT_ID(N'compras.Recepciones', N'U') IS NULL
CREATE TABLE compras.Recepciones (
    IdRecepcion      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Recepciones PRIMARY KEY,
    Numero           VARCHAR(15)    NOT NULL CONSTRAINT UQ_Recepciones_Numero UNIQUE,
    IdOrdenCompra    INT            NOT NULL CONSTRAINT FK_Rec_OC          REFERENCES compras.OrdenesCompra (IdOrdenCompra),
    IdProveedor      INT            NOT NULL CONSTRAINT FK_Rec_Proveedores REFERENCES compras.Proveedores (IdProveedor),
    IdBodega         INT            NOT NULL CONSTRAINT FK_Rec_Bodegas     REFERENCES inv.Bodegas (IdBodega),
    FechaRecepcion   DATE           NOT NULL,
    FechaEsperada    DATE           NOT NULL,
    SerieFactura     VARCHAR(20)    NULL,
    NumeroFactura    VARCHAR(30)    NOT NULL,
    Cumplimiento     VARCHAR(10)    NOT NULL,
    DiasDiferencia   INT            NOT NULL,
    Subtotal         DECIMAL(18,2)  NOT NULL,
    Iva              DECIMAL(18,2)  NOT NULL,
    Total            DECIMAL(18,2)  NOT NULL,
    Observaciones    NVARCHAR(300)  NULL,
    FechaCreacion    DATETIME2(0)   NOT NULL CONSTRAINT DF_Rec_FC DEFAULT (SYSDATETIME()),
    RecibidoPor      NVARCHAR(100)  NOT NULL,
    CONSTRAINT UQ_Rec_Factura      UNIQUE (IdProveedor, SerieFactura, NumeroFactura),
    CONSTRAINT CK_Rec_Cumplimiento CHECK (Cumplimiento IN ('ATiempo', 'Retraso', 'Anticipada')),
    CONSTRAINT CK_Rec_Montos       CHECK (Subtotal > 0 AND Iva >= 0 AND Total = Subtotal + Iva)
);
GO

IF OBJECT_ID(N'compras.RecepcionesDetalle', N'U') IS NULL
CREATE TABLE compras.RecepcionesDetalle (
    IdRecepcionDetalle  INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_RecepcionesDetalle PRIMARY KEY,
    IdRecepcion         INT            NOT NULL CONSTRAINT FK_RecD_Rec       REFERENCES compras.Recepciones (IdRecepcion),
    IdDetalleOrden      INT            NOT NULL CONSTRAINT FK_RecD_OCD       REFERENCES compras.OrdenesCompraDetalle (IdDetalle),
    IdProducto          INT            NOT NULL CONSTRAINT FK_RecD_Productos REFERENCES inv.Productos (IdProducto),
    Cantidad            DECIMAL(18,2)  NOT NULL,
    CostoUnitario       DECIMAL(18,4)  NOT NULL,
    Subtotal            AS CAST(Cantidad * CostoUnitario AS DECIMAL(18,2)) PERSISTED,
    CONSTRAINT UQ_RecD_Linea    UNIQUE (IdRecepcion, IdDetalleOrden),
    CONSTRAINT CK_RecD_Cantidad CHECK (Cantidad > 0),
    CONSTRAINT CK_RecD_Costo    CHECK (CostoUnitario > 0)
);
GO

/* ============================ CUENTAS POR PAGAR ============================ */
IF OBJECT_ID(N'compras.CuentasPorPagar', N'U') IS NULL
CREATE TABLE compras.CuentasPorPagar (
    IdCuentaPagar      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_CuentasPorPagar PRIMARY KEY,
    Numero             VARCHAR(15)    NOT NULL CONSTRAINT UQ_CxP_Numero UNIQUE,
    IdRecepcion        INT            NOT NULL CONSTRAINT UQ_CxP_Recepcion UNIQUE
                                               CONSTRAINT FK_CxP_Rec REFERENCES compras.Recepciones (IdRecepcion),
    IdProveedor        INT            NOT NULL CONSTRAINT FK_CxP_Proveedores REFERENCES compras.Proveedores (IdProveedor),
    FechaEmision       DATE           NOT NULL,
    FechaVencimiento   DATE           NOT NULL,
    Monto              DECIMAL(18,2)  NOT NULL,
    Saldo              DECIMAL(18,2)  NOT NULL,
    Estado             VARCHAR(10)    NOT NULL CONSTRAINT DF_CxP_Estado DEFAULT ('Pendiente'),
    FechaCreacion      DATETIME2(0)   NOT NULL CONSTRAINT DF_CxP_FC     DEFAULT (SYSDATETIME()),
    FechaModificacion  DATETIME2(0)   NULL,
    RowVersion         ROWVERSION     NOT NULL,
    CONSTRAINT CK_CxP_Fechas  CHECK (FechaVencimiento >= FechaEmision),
    CONSTRAINT CK_CxP_Montos  CHECK (Monto > 0 AND Saldo >= 0 AND Saldo <= Monto),
    CONSTRAINT CK_CxP_Estado  CHECK ((Estado = 'Pendiente' AND Saldo = Monto)
                                  OR (Estado = 'Parcial'   AND Saldo > 0 AND Saldo < Monto)
                                  OR (Estado = 'Pagada'    AND Saldo = 0))
);
GO

/* ===================== PAGOS A PROVEEDORES (API bancaria) =====================
   Flujo de una transferencia:
     1) sp_Pago_Iniciar      -> Estado 'Pendiente' (se reserva el monto)
     2) backend llama a la API bancaria simulada (servicio independiente)
     3) sp_Pago_Confirmar    -> 'Aprobado' (rebaja saldo) o 'Rechazado'
   OperacionId garantiza idempotencia: reintentos no duplican pagos.
   Cheque y Efectivo se registran directamente como 'Aprobado'.
   ============================================================================ */
IF OBJECT_ID(N'compras.PagosProveedor', N'U') IS NULL
CREATE TABLE compras.PagosProveedor (
    IdPago             INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PagosProveedor PRIMARY KEY,
    Numero             VARCHAR(15)       NOT NULL CONSTRAINT UQ_Pagos_Numero UNIQUE,
    IdCuentaPagar      INT               NOT NULL CONSTRAINT FK_Pago_CxP        REFERENCES compras.CuentasPorPagar (IdCuentaPagar),
    IdProveedor        INT               NOT NULL CONSTRAINT FK_Pago_Proveedores REFERENCES compras.Proveedores (IdProveedor),
    OperacionId        UNIQUEIDENTIFIER  NOT NULL CONSTRAINT UQ_Pagos_Operacion UNIQUE,
    Monto              DECIMAL(18,2)     NOT NULL,
    Metodo             VARCHAR(15)       NOT NULL,
    Banco              NVARCHAR(60)      NULL,
    CuentaDestino      VARCHAR(30)       NULL,
    ReferenciaBanco    VARCHAR(50)       NULL,
    Estado             VARCHAR(10)       NOT NULL,
    MensajeBanco       NVARCHAR(250)     NULL,
    Intentos           INT               NOT NULL CONSTRAINT DF_Pagos_Intentos  DEFAULT (0),
    FechaSolicitud     DATETIME2(0)      NOT NULL CONSTRAINT DF_Pagos_Solicitud DEFAULT (SYSDATETIME()),
    FechaConfirmacion  DATETIME2(0)      NULL,
    RegistradoPor      NVARCHAR(100)     NOT NULL,
    ConfirmadoPor      NVARCHAR(100)     NULL,
    CONSTRAINT CK_Pago_Monto       CHECK (Monto > 0),
    CONSTRAINT CK_Pago_Metodo      CHECK (Metodo IN ('Transferencia', 'Cheque', 'Efectivo')),
    CONSTRAINT CK_Pago_Estado      CHECK (Estado IN ('Pendiente', 'Aprobado', 'Rechazado')),
    CONSTRAINT CK_Pago_Intentos    CHECK (Intentos >= 0),
    CONSTRAINT CK_Pago_Confirmado  CHECK (Estado = 'Pendiente' OR FechaConfirmacion IS NOT NULL),
    CONSTRAINT CK_Pago_Referencia  CHECK (Estado <> 'Aprobado' OR Metodo = 'Efectivo' OR ReferenciaBanco IS NOT NULL),
    CONSTRAINT CK_Pago_Transfer    CHECK (Metodo <> 'Transferencia' OR (Banco IS NOT NULL AND CuentaDestino IS NOT NULL))
);
GO

/* =============================== ÍNDICES =============================== */
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Proveedores_Nombre')
    CREATE INDEX IX_Proveedores_Nombre ON compras.Proveedores (Nombre);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Proveedores_Estado_Tipo')
    CREATE INDEX IX_Proveedores_Estado_Tipo ON compras.Proveedores (Estado, TipoPago) INCLUDE (Nombre, IdCategoria);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_OC_Proveedor_Fecha')
    CREATE INDEX IX_OC_Proveedor_Fecha ON compras.OrdenesCompra (IdProveedor, FechaOrden) INCLUDE (Estado, Total);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_OC_Estado_FechaEsperada')
    CREATE INDEX IX_OC_Estado_FechaEsperada ON compras.OrdenesCompra (Estado, FechaEsperada);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_OC_Bodega')
    CREATE INDEX IX_OC_Bodega ON compras.OrdenesCompra (IdBodega);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_OCH_Orden')
    CREATE INDEX IX_OCH_Orden ON compras.OrdenesCompraHistorial (IdOrdenCompra, Fecha);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Rec_Orden')
    CREATE INDEX IX_Rec_Orden ON compras.Recepciones (IdOrdenCompra);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Rec_Proveedor_Fecha')
    CREATE INDEX IX_Rec_Proveedor_Fecha ON compras.Recepciones (IdProveedor, FechaRecepcion) INCLUDE (Cumplimiento, DiasDiferencia, Total);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_RecD_DetalleOrden')
    CREATE INDEX IX_RecD_DetalleOrden ON compras.RecepcionesDetalle (IdDetalleOrden);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_CxP_Estado_Vencimiento')
    CREATE INDEX IX_CxP_Estado_Vencimiento ON compras.CuentasPorPagar (Estado, FechaVencimiento) INCLUDE (Saldo, IdProveedor);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_CxP_Proveedor')
    CREATE INDEX IX_CxP_Proveedor ON compras.CuentasPorPagar (IdProveedor);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Pagos_CxP')
    CREATE INDEX IX_Pagos_CxP ON compras.PagosProveedor (IdCuentaPagar) INCLUDE (Estado, Monto);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Pagos_Pendientes')
    CREATE INDEX IX_Pagos_Pendientes ON compras.PagosProveedor (FechaSolicitud) WHERE Estado = 'Pendiente';
GO

PRINT N'[OK] 05 - Tablas de Proveedores y Compras.';
GO
