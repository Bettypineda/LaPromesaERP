/* =====================================================================
   LA PROMESA ERP  |  Datos de prueba FICTICIOS
   ---------------------------------------------------------------------
   - Catálogos (categorías, bodegas, productos): MERGE, repetible.
   - Proveedores, órdenes, recepciones y pagos se crean LLAMANDO A LOS
     PROCEDIMIENTOS ALMACENADOS, así los datos respetan todas las reglas
     (y sirven como primera prueba del proceso completo).
   - Las fechas son relativas a HOY, para que los reportes siempre
     tengan información de "vencidas", "por vencer" y "atrasadas".
   - Nombres, NIT, teléfonos, correos y cuentas son inventados.
     Los NIT cumplen el dígito verificador, pero no corresponden a
     contribuyentes reales a propósito.
   - El pago por transferencia simula la respuesta del banco (SIM-...).
   ===================================================================== */
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
USE LaPromesaERP;
GO

/* ---------------------------- CATÁLOGOS ---------------------------- */
MERGE compras.CategoriasProveedor AS t
USING (VALUES
    (N'Abarrotes',      N'Productos de consumo básico empacados'),
    (N'Bebidas',        N'Gaseosas, aguas y jugos'),
    (N'Lácteos',        N'Leche y derivados'),
    (N'Granos básicos', N'Frijol, maíz, arroz a granel'),
    (N'Limpieza',       N'Detergentes y productos de limpieza'),
    (N'Snacks',         N'Golosinas y galletas')
) AS s (Nombre, Descripcion)
ON t.Nombre = s.Nombre
WHEN NOT MATCHED THEN INSERT (Nombre, Descripcion, CreadoPor) VALUES (s.Nombre, s.Descripcion, N'seed');
GO

MERGE inv.Bodegas AS t
USING (VALUES
    ('BOD-01', N'Bodega Central',       N'Cuilapa, Santa Rosa'),
    ('BOD-02', N'Bodega Barberena',     N'Barberena, Santa Rosa'),
    ('BOD-03', N'Bodega Chiquimulilla', N'Chiquimulilla, Santa Rosa'),
    ('BOD-04', N'Bodega Escuintla',     N'Escuintla, Escuintla'),
    ('BOD-05', N'Bodega Jutiapa',       N'Jutiapa, Jutiapa')
) AS s (Codigo, Nombre, Ubicacion)
ON t.Codigo = s.Codigo
WHEN NOT MATCHED THEN INSERT (Codigo, Nombre, Ubicacion) VALUES (s.Codigo, s.Nombre, s.Ubicacion);
GO

MERGE inv.Productos AS t
USING (VALUES
    ('PRD-001', N'Azúcar blanca 1 lb',          N'Unidad',  4.25, 100),
    ('PRD-002', N'Arroz blanco 1 lb',           N'Unidad',  5.10, 100),
    ('PRD-003', N'Aceite vegetal 1 L',          N'Unidad', 18.75,  50),
    ('PRD-004', N'Gaseosa 2.5 L',               N'Unidad', 14.50,  80),
    ('PRD-005', N'Leche entera 1 L',            N'Unidad', 10.90,  60),
    ('PRD-006', N'Frijol negro 1 lb',           N'Unidad',  7.35, 100),
    ('PRD-007', N'Detergente en polvo 1 kg',    N'Unidad', 22.50,  40),
    ('PRD-008', N'Galletas surtidas paquete',   N'Unidad', 12.00,  50)
) AS s (Codigo, Nombre, UnidadMedida, CostoPromedio, StockMinimo)
ON t.Codigo = s.Codigo
WHEN NOT MATCHED THEN INSERT (Codigo, Nombre, UnidadMedida, CostoPromedio, StockMinimo)
                      VALUES (s.Codigo, s.Nombre, s.UnidadMedida, s.CostoPromedio, s.StockMinimo);
GO

/* --------------------------- PROVEEDORES --------------------------- */
DECLARE @p TABLE (Nombre NVARCHAR(150), Nit VARCHAR(15), Categoria NVARCHAR(50), Contacto NVARCHAR(100),
                  Telefono VARCHAR(9), Email NVARCHAR(150), Direccion NVARCHAR(200), Departamento NVARCHAR(50),
                  TipoPago VARCHAR(10), Dias INT, Limite DECIMAL(18,2), Banco NVARCHAR(60), Cuenta VARCHAR(30));
INSERT INTO @p VALUES
 (N'Distribuidora El Progreso Comercial', '4512378-0', N'Abarrotes',      N'Mario Pérez',    '2360-1111', N'ventas@elprogreso.test',   N'Km 12.5 Carretera al Atlántico', N'Guatemala',  'Credito', 30, 50000, N'Banco Simulado GT', 'SIM-000-1234567'),
 (N'Embotelladora del Sur',               '6893214-6', N'Bebidas',        N'Ana López',      '7880-2222', N'pedidos@embosur.test',     N'Zona 3, Escuintla',              N'Escuintla',  'Credito', 15, 30000, N'Banco Simulado GT', 'SIM-000-2345678'),
 (N'Alimentos Santa Rosa',                '1234567-9', N'Abarrotes',      N'Carlos Ruiz',    '7886-3333', N'info@alimentossr.test',    N'Barrio El Centro, Cuilapa',      N'Santa Rosa', 'Contado',  0,     0, NULL, NULL),
 (N'Lácteos del Pacífico',                '9876543-4', N'Lácteos',        N'Lucía Mendoza',  '7889-4444', N'ventas@lacteospac.test',   N'Puerto San José',                N'Escuintla',  'Credito', 15, 20000, N'Banco Simulado GT', 'SIM-000-3456789'),
 (N'Granos y Semillas Cuilapa',           '5544332-K', N'Granos básicos', N'Jorge Castillo', '7886-5555', N'granos@cuilapa.test',      N'Aldea Los Esclavos, Cuilapa',    N'Santa Rosa', 'Contado',  0,     0, NULL, NULL),
 (N'Química Limpia',                      '7788112-5', N'Limpieza',       N'María Ortiz',    '2470-6666', N'ventas@quimicalimpia.test',N'Zona 12, Guatemala',             N'Guatemala',  'Credito', 30, 15000, N'Banco Simulado GT', 'SIM-000-4567890'),
 (N'Snacks del Oriente',                  '3216549-8', N'Snacks',         N'Pedro Gómez',    '7940-7777', N'ventas@snacksoriente.test',N'Jutiapa',                        N'Jutiapa',    'Contado',  0,     0, NULL, NULL);

DECLARE @nombre NVARCHAR(150), @nit VARCHAR(15), @cat NVARCHAR(50), @contacto NVARCHAR(100), @tel VARCHAR(9),
        @email NVARCHAR(150), @dir NVARCHAR(200), @depto NVARCHAR(50), @tipo VARCHAR(10), @dias INT,
        @limite DECIMAL(18,2), @banco NVARCHAR(60), @cuenta VARCHAR(30), @idCat INT, @idProv INT;

DECLARE cur CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM @p;
OPEN cur;
FETCH NEXT FROM cur INTO @nombre, @nit, @cat, @contacto, @tel, @email, @dir, @depto, @tipo, @dias, @limite, @banco, @cuenta;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM compras.Proveedores WHERE Nit = @nit)
    BEGIN
        SELECT @idCat = IdCategoria FROM compras.CategoriasProveedor WHERE Nombre = @cat;
        EXEC compras.sp_Proveedor_Crear
             @Nombre = @nombre, @Nit = @nit, @IdCategoria = @idCat, @Contacto = @contacto, @Telefono = @tel,
             @Email = @email, @Direccion = @dir, @Departamento = @depto, @TipoPago = @tipo, @DiasCredito = @dias,
             @LimiteCredito = @limite, @Banco = @banco, @NumeroCuenta = @cuenta,
             @Usuario = N'sara.compras', @IdProveedor = @idProv OUTPUT;
    END
    FETCH NEXT FROM cur INTO @nombre, @nit, @cat, @contacto, @tel, @email, @dir, @depto, @tipo, @dias, @limite, @banco, @cuenta;
END
CLOSE cur;
DEALLOCATE cur;
GO

/* ------------- PROCESO COMPLETO: órdenes, recepciones y pagos ------------- */
IF EXISTS (SELECT 1 FROM compras.OrdenesCompra)
BEGIN
    PRINT N'Ya existen órdenes de compra: se omite la carga del proceso.';
    RETURN;
END

DECLARE @hoy DATE = CAST(GETDATE() AS DATE);
DECLARE @comprador NVARCHAR(100) = N'sara.compras',
        @gerente   NVARCHAR(100) = N'gerente.general',
        @bodeguero NVARCHAR(100) = N'bodega.central',
        @tesorero  NVARCHAR(100) = N'tesoreria';

DECLARE @prv1 INT = (SELECT IdProveedor FROM compras.Proveedores WHERE Nit = '4512378-0'),
        @prv2 INT = (SELECT IdProveedor FROM compras.Proveedores WHERE Nit = '6893214-6'),
        @prv3 INT = (SELECT IdProveedor FROM compras.Proveedores WHERE Nit = '1234567-9'),
        @prv4 INT = (SELECT IdProveedor FROM compras.Proveedores WHERE Nit = '9876543-4'),
        @prv5 INT = (SELECT IdProveedor FROM compras.Proveedores WHERE Nit = '5544332-K'),
        @prv6 INT = (SELECT IdProveedor FROM compras.Proveedores WHERE Nit = '7788112-5'),
        @prv7 INT = (SELECT IdProveedor FROM compras.Proveedores WHERE Nit = '3216549-8');

DECLARE @b1 INT = (SELECT IdBodega FROM inv.Bodegas WHERE Codigo = 'BOD-01'),
        @b2 INT = (SELECT IdBodega FROM inv.Bodegas WHERE Codigo = 'BOD-02'),
        @b3 INT = (SELECT IdBodega FROM inv.Bodegas WHERE Codigo = 'BOD-03'),
        @b4 INT = (SELECT IdBodega FROM inv.Bodegas WHERE Codigo = 'BOD-04'),
        @b5 INT = (SELECT IdBodega FROM inv.Bodegas WHERE Codigo = 'BOD-05');

DECLARE @a1 INT = (SELECT IdProducto FROM inv.Productos WHERE Codigo = 'PRD-001'),
        @a2 INT = (SELECT IdProducto FROM inv.Productos WHERE Codigo = 'PRD-002'),
        @a3 INT = (SELECT IdProducto FROM inv.Productos WHERE Codigo = 'PRD-003'),
        @a4 INT = (SELECT IdProducto FROM inv.Productos WHERE Codigo = 'PRD-004'),
        @a5 INT = (SELECT IdProducto FROM inv.Productos WHERE Codigo = 'PRD-005'),
        @a6 INT = (SELECT IdProducto FROM inv.Productos WHERE Codigo = 'PRD-006'),
        @a7 INT = (SELECT IdProducto FROM inv.Productos WHERE Codigo = 'PRD-007'),
        @a8 INT = (SELECT IdProducto FROM inv.Productos WHERE Codigo = 'PRD-008');

DECLARE @oc INT, @rc INT, @pg INT, @cxp INT, @det NVARCHAR(MAX), @rec NVARCHAR(MAX), @f DATE, @e DATE, @fr DATE;

/* OC 1: Recibida completa A TIEMPO; cuenta por pagar vencida con abono por cheque */
SET @f = DATEADD(DAY, -45, @hoy); SET @e = DATEADD(DAY, -38, @hoy);
SET @det = CONCAT(N'[{"idProducto":', @a1, N',"cantidad":200,"costoUnitario":4.25},',
                  N'{"idProducto":', @a2, N',"cantidad":150,"costoUnitario":5.10},',
                  N'{"idProducto":', @a6, N',"cantidad":100,"costoUnitario":7.35}]');
EXEC compras.sp_OrdenCompra_Crear @IdProveedor = @prv1, @IdBodega = @b1, @FechaOrden = @f, @FechaEsperada = @e,
     @Observaciones = N'Reabastecimiento mensual de abarrotes', @Detalle = @det, @Usuario = @comprador, @IdOrdenCompra = @oc OUTPUT;
EXEC compras.sp_OrdenCompra_Aprobar @IdOrdenCompra = @oc, @Usuario = @gerente;
SET @rec = (SELECT IdDetalle AS idDetalle, CantidadPedida - CantidadRecibida AS cantidad
            FROM compras.OrdenesCompraDetalle WHERE IdOrdenCompra = @oc FOR JSON PATH);
EXEC compras.sp_Recepcion_Registrar @IdOrdenCompra = @oc, @FechaRecepcion = @e, @SerieFactura = 'A', @NumeroFactura = '1001',
     @Detalle = @rec, @Usuario = @bodeguero, @IdRecepcion = @rc OUTPUT;
SET @cxp = (SELECT IdCuentaPagar FROM compras.CuentasPorPagar WHERE IdRecepcion = @rc);
DECLARE @op1 UNIQUEIDENTIFIER = NEWID();
EXEC compras.sp_Pago_Iniciar @IdCuentaPagar = @cxp, @OperacionId = @op1, @Monto = 500.00, @Metodo = 'Cheque',
     @Referencia = 'CHQ-000101', @Usuario = @tesorero, @IdPago = @pg OUTPUT;

/* OC 2: dos recepciones con RETRASO (parcial y luego total); primera pagada por transferencia */
SET @f = DATEADD(DAY, -30, @hoy); SET @e = DATEADD(DAY, -25, @hoy);
SET @det = CONCAT(N'[{"idProducto":', @a4, N',"cantidad":300,"costoUnitario":14.50}]');
EXEC compras.sp_OrdenCompra_Crear @IdProveedor = @prv2, @IdBodega = @b2, @FechaOrden = @f, @FechaEsperada = @e,
     @Detalle = @det, @Usuario = @comprador, @IdOrdenCompra = @oc OUTPUT;
EXEC compras.sp_OrdenCompra_Aprobar @IdOrdenCompra = @oc, @Usuario = @gerente;
SET @fr = DATEADD(DAY, -22, @hoy);
SET @rec = (SELECT IdDetalle AS idDetalle, 150 AS cantidad FROM compras.OrdenesCompraDetalle WHERE IdOrdenCompra = @oc FOR JSON PATH);
EXEC compras.sp_Recepcion_Registrar @IdOrdenCompra = @oc, @FechaRecepcion = @fr, @SerieFactura = 'B', @NumeroFactura = '2001',
     @Observaciones = N'Proveedor entregó la mitad por falta de transporte', @Detalle = @rec, @Usuario = @bodeguero, @IdRecepcion = @rc OUTPUT;
SET @cxp = (SELECT IdCuentaPagar FROM compras.CuentasPorPagar WHERE IdRecepcion = @rc);
DECLARE @op2 UNIQUEIDENTIFIER = NEWID(), @montoCxp DECIMAL(18,2) = (SELECT Saldo FROM compras.CuentasPorPagar WHERE IdCuentaPagar = @cxp);
EXEC compras.sp_Pago_Iniciar @IdCuentaPagar = @cxp, @OperacionId = @op2, @Monto = @montoCxp, @Metodo = 'Transferencia',
     @Usuario = @tesorero, @IdPago = @pg OUTPUT;
EXEC compras.sp_Pago_Confirmar @IdPago = @pg, @Aprobado = 1, @ReferenciaBanco = 'SIM-TRX-000001',
     @MensajeBanco = N'Respuesta simulada de la API bancaria (datos de prueba)', @Usuario = @tesorero;
SET @fr = DATEADD(DAY, -15, @hoy);
SET @rec = (SELECT IdDetalle AS idDetalle, CantidadPedida - CantidadRecibida AS cantidad FROM compras.OrdenesCompraDetalle WHERE IdOrdenCompra = @oc FOR JSON PATH);
EXEC compras.sp_Recepcion_Registrar @IdOrdenCompra = @oc, @FechaRecepcion = @fr, @SerieFactura = 'B', @NumeroFactura = '2002',
     @Detalle = @rec, @Usuario = @bodeguero, @IdRecepcion = @rc OUTPUT;

/* OC 3: recepción ANTICIPADA, cuenta por pagar por vencer */
SET @f = DATEADD(DAY, -12, @hoy); SET @e = DATEADD(DAY, -5, @hoy); SET @fr = DATEADD(DAY, -7, @hoy);
SET @det = CONCAT(N'[{"idProducto":', @a5, N',"cantidad":240,"costoUnitario":10.90}]');
EXEC compras.sp_OrdenCompra_Crear @IdProveedor = @prv4, @IdBodega = @b4, @FechaOrden = @f, @FechaEsperada = @e,
     @Detalle = @det, @Usuario = @comprador, @IdOrdenCompra = @oc OUTPUT;
EXEC compras.sp_OrdenCompra_Aprobar @IdOrdenCompra = @oc, @Usuario = @gerente;
SET @rec = (SELECT IdDetalle AS idDetalle, CantidadPedida AS cantidad FROM compras.OrdenesCompraDetalle WHERE IdOrdenCompra = @oc FOR JSON PATH);
EXEC compras.sp_Recepcion_Registrar @IdOrdenCompra = @oc, @FechaRecepcion = @fr, @SerieFactura = 'L', @NumeroFactura = '3001',
     @Detalle = @rec, @Usuario = @bodeguero, @IdRecepcion = @rc OUTPUT;

/* OC 4: proveedor de CONTADO, recepción PARCIAL y pago en efectivo */
SET @f = DATEADD(DAY, -6, @hoy); SET @e = DATEADD(DAY, -2, @hoy);
SET @det = CONCAT(N'[{"idProducto":', @a3, N',"cantidad":120,"costoUnitario":18.75},',
                  N'{"idProducto":', @a1, N',"cantidad":50,"costoUnitario":4.30}]');
EXEC compras.sp_OrdenCompra_Crear @IdProveedor = @prv3, @IdBodega = @b1, @FechaOrden = @f, @FechaEsperada = @e,
     @Detalle = @det, @Usuario = @comprador, @IdOrdenCompra = @oc OUTPUT;
EXEC compras.sp_OrdenCompra_Aprobar @IdOrdenCompra = @oc, @Usuario = @gerente;
SET @rec = (SELECT IdDetalle AS idDetalle, 60 AS cantidad FROM compras.OrdenesCompraDetalle
            WHERE IdOrdenCompra = @oc AND IdProducto = @a3 FOR JSON PATH);
EXEC compras.sp_Recepcion_Registrar @IdOrdenCompra = @oc, @FechaRecepcion = @e, @NumeroFactura = '4001',
     @Detalle = @rec, @Usuario = @bodeguero, @IdRecepcion = @rc OUTPUT;
SET @cxp = (SELECT IdCuentaPagar FROM compras.CuentasPorPagar WHERE IdRecepcion = @rc);
DECLARE @op3 UNIQUEIDENTIFIER = NEWID();
SET @montoCxp = (SELECT Saldo FROM compras.CuentasPorPagar WHERE IdCuentaPagar = @cxp);
EXEC compras.sp_Pago_Iniciar @IdCuentaPagar = @cxp, @OperacionId = @op3, @Monto = @montoCxp, @Metodo = 'Efectivo',
     @Usuario = @tesorero, @IdPago = @pg OUTPUT;

/* OC 5: aprobada, pendiente de recibir (entrega futura) */
SET @f = DATEADD(DAY, -3, @hoy); SET @e = DATEADD(DAY, 4, @hoy);
SET @det = CONCAT(N'[{"idProducto":', @a7, N',"cantidad":80,"costoUnitario":22.50}]');
EXEC compras.sp_OrdenCompra_Crear @IdProveedor = @prv6, @IdBodega = @b5, @FechaOrden = @f, @FechaEsperada = @e,
     @Detalle = @det, @Usuario = @comprador, @IdOrdenCompra = @oc OUTPUT;
EXEC compras.sp_OrdenCompra_Aprobar @IdOrdenCompra = @oc, @Usuario = @gerente;

/* OC 6: pendiente de aprobación */
SET @f = DATEADD(DAY, -1, @hoy); SET @e = DATEADD(DAY, 3, @hoy);
SET @det = CONCAT(N'[{"idProducto":', @a6, N',"cantidad":200,"costoUnitario":7.10}]');
EXEC compras.sp_OrdenCompra_Crear @IdProveedor = @prv5, @IdBodega = @b3, @FechaOrden = @f, @FechaEsperada = @e,
     @Detalle = @det, @Usuario = @comprador, @IdOrdenCompra = @oc OUTPUT;

/* OC 7: anulada con motivo */
SET @f = DATEADD(DAY, -20, @hoy); SET @e = DATEADD(DAY, -14, @hoy);
SET @det = CONCAT(N'[{"idProducto":', @a8, N',"cantidad":100,"costoUnitario":12.00}]');
EXEC compras.sp_OrdenCompra_Crear @IdProveedor = @prv1, @IdBodega = @b1, @FechaOrden = @f, @FechaEsperada = @e,
     @Detalle = @det, @Usuario = @comprador, @IdOrdenCompra = @oc OUTPUT;
EXEC compras.sp_OrdenCompra_Anular @IdOrdenCompra = @oc, @Motivo = N'El proveedor no tenía existencia del producto solicitado',
     @Usuario = @gerente;

/* OC 8: aprobada y ATRASADA (la fecha esperada ya pasó y no ha llegado) */
SET @f = DATEADD(DAY, -10, @hoy); SET @e = DATEADD(DAY, -4, @hoy);
SET @det = CONCAT(N'[{"idProducto":', @a4, N',"cantidad":100,"costoUnitario":14.50}]');
EXEC compras.sp_OrdenCompra_Crear @IdProveedor = @prv2, @IdBodega = @b2, @FechaOrden = @f, @FechaEsperada = @e,
     @Detalle = @det, @Usuario = @comprador, @IdOrdenCompra = @oc OUTPUT;
EXEC compras.sp_OrdenCompra_Aprobar @IdOrdenCompra = @oc, @Usuario = @gerente;

/* Proveedor inactivado con motivo (no tiene órdenes abiertas) */
EXEC compras.sp_Proveedor_Inactivar @IdProveedor = @prv7,
     @Motivo = N'Proveedor dejó de distribuir en la región de Santa Rosa', @Usuario = @gerente;
GO

/* --------------------------- RESUMEN --------------------------- */
SELECT N'Categorías' AS Tabla, COUNT(*) AS Registros FROM compras.CategoriasProveedor
UNION ALL SELECT N'Bodegas',            COUNT(*) FROM inv.Bodegas
UNION ALL SELECT N'Productos',          COUNT(*) FROM inv.Productos
UNION ALL SELECT N'Proveedores',        COUNT(*) FROM compras.Proveedores
UNION ALL SELECT N'Órdenes de compra',  COUNT(*) FROM compras.OrdenesCompra
UNION ALL SELECT N'Recepciones',        COUNT(*) FROM compras.Recepciones
UNION ALL SELECT N'Cuentas por pagar',  COUNT(*) FROM compras.CuentasPorPagar
UNION ALL SELECT N'Pagos',              COUNT(*) FROM compras.PagosProveedor
UNION ALL SELECT N'Movimientos kardex', COUNT(*) FROM inv.MovimientosInventario
UNION ALL SELECT N'Bitácora',           COUNT(*) FROM aud.Bitacora;
GO
PRINT N'[OK] Datos de prueba.';
GO
