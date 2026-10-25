/* =====================================================================
   LA PROMESA ERP  |  Pruebas automáticas de reglas de negocio
   ---------------------------------------------------------------------
   Requisito: haber ejecutado 00_ejecutar_todo.sql (con datos de prueba).
   Cada prueba intenta una operación PROHIBIDA y verifica que la base
   de datos la rechace con el código de error esperado.
   Las operaciones rechazadas se revierten, así que este script NO
   modifica los datos y es repetible.
   Resultado: una tabla con PASÓ / FALLÓ por prueba y un resumen.
   ===================================================================== */
SET NOCOUNT ON;
USE LaPromesaERP;
GO

DECLARE @r TABLE (
    N         INT IDENTITY(1,1),
    Prueba    NVARCHAR(200),
    Esperado  INT,
    Obtenido  INT,
    Mensaje   NVARCHAR(4000)
);

DECLARE @hoy DATE = CAST(GETDATE() AS DATE), @ayer DATE = DATEADD(DAY, -1, CAST(GETDATE() AS DATE));
DECLARE @catAbarrotes INT = (SELECT IdCategoria FROM compras.CategoriasProveedor WHERE Nombre = N'Abarrotes');
DECLARE @prv1 INT = (SELECT IdProveedor FROM compras.Proveedores WHERE Nit = '4512378-0'),
        @prv2 INT = (SELECT IdProveedor FROM compras.Proveedores WHERE Nit = '6893214-6'),
        @prv7 INT = (SELECT IdProveedor FROM compras.Proveedores WHERE Nit = '3216549-8');
DECLARE @b1  INT = (SELECT IdBodega FROM inv.Bodegas WHERE Codigo = 'BOD-01');
DECLARE @a1  INT = (SELECT IdProducto FROM inv.Productos WHERE Codigo = 'PRD-001');
DECLARE @ocPendiente INT = (SELECT TOP (1) IdOrdenCompra FROM compras.OrdenesCompra WHERE Estado = 'Pendiente' ORDER BY IdOrdenCompra);
DECLARE @ocAprobada  INT = (SELECT TOP (1) IdOrdenCompra FROM compras.OrdenesCompra WHERE Estado = 'Aprobada' ORDER BY IdOrdenCompra);
DECLARE @ocParcial   INT = (SELECT TOP (1) IdOrdenCompra FROM compras.OrdenesCompra WHERE Estado = 'Parcial' ORDER BY IdOrdenCompra);
DECLARE @ocAtrasada  INT = (SELECT TOP (1) IdOrdenCompra FROM compras.OrdenesCompra WHERE Estado = 'Aprobada' AND IdProveedor = @prv2);
DECLARE @recep       INT = (SELECT TOP (1) IdRecepcion FROM compras.Recepciones ORDER BY IdRecepcion);
DECLARE @cxpAbierta  INT = (SELECT TOP (1) IdCuentaPagar FROM compras.CuentasPorPagar WHERE Estado <> 'Pagada' ORDER BY IdCuentaPagar);
DECLARE @det NVARCHAR(MAX), @rec NVARCHAR(MAX), @rv BINARY(8), @id INT, @op UNIQUEIDENTIFIER;

/* ------------------------------- PROVEEDORES ------------------------------- */
BEGIN TRY
    EXEC compras.sp_Proveedor_Crear @Nombre = N'Prueba NIT', @Nit = '1234567-1', @IdCategoria = @catAbarrotes,
         @TipoPago = 'Contado', @Usuario = N'pruebas', @IdProveedor = @id OUTPUT;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Rechaza NIT con dígito verificador incorrecto', 51011, 0, N'No hubo error');
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Rechaza NIT con dígito verificador incorrecto', 51011, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH

BEGIN TRY
    EXEC compras.sp_Proveedor_Crear @Nombre = N'Prueba duplicado', @Nit = '45123780', @IdCategoria = @catAbarrotes,
         @TipoPago = 'Contado', @Usuario = N'pruebas', @IdProveedor = @id OUTPUT;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Rechaza NIT duplicado (aunque se escriba sin guion)', 53002, 0, N'No hubo error');
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Rechaza NIT duplicado (aunque se escriba sin guion)', 53002, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH

BEGIN TRY
    EXEC compras.sp_Proveedor_Crear @Nombre = N'Prueba contado', @Nit = '7654321-8', @IdCategoria = @catAbarrotes,
         @TipoPago = 'Contado', @DiasCredito = 30, @Usuario = N'pruebas', @IdProveedor = @id OUTPUT;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Contado con días de crédito', 51015, 0, N'No hubo error');
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Contado con días de crédito', 51015, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH

BEGIN TRY
    EXEC compras.sp_Proveedor_Crear @Nombre = N'Prueba crédito', @Nit = '7654321-8', @IdCategoria = @catAbarrotes,
         @TipoPago = 'Credito', @DiasCredito = 0, @Usuario = N'pruebas', @IdProveedor = @id OUTPUT;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Crédito con 0 días', 51015, 0, N'No hubo error');
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Crédito con 0 días', 51015, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH

BEGIN TRY
    EXEC compras.sp_Proveedor_Crear @Nombre = N'Prueba correo', @Nit = '7654321-8', @IdCategoria = @catAbarrotes,
         @Email = N'correo-sin-arroba', @TipoPago = 'Contado', @Usuario = N'pruebas', @IdProveedor = @id OUTPUT;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Correo con formato inválido', 51013, 0, N'No hubo error');
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Correo con formato inválido', 51013, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH

BEGIN TRY
    EXEC compras.sp_Proveedor_Crear @Nombre = N'Prueba teléfono', @Nit = '7654321-8', @IdCategoria = @catAbarrotes,
         @Telefono = '1234', @TipoPago = 'Contado', @Usuario = N'pruebas', @IdProveedor = @id OUTPUT;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Teléfono inválido', 51012, 0, N'No hubo error');
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Teléfono inválido', 51012, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH

BEGIN TRY
    EXEC compras.sp_Proveedor_Actualizar @IdProveedor = @prv1, @Nombre = N'Cambio con versión vieja', @Nit = '4512378-0',
         @IdCategoria = @catAbarrotes, @TipoPago = 'Credito', @DiasCredito = 30, @LimiteCredito = 50000,
         @RowVersion = 0x0000000000000001, @Usuario = N'pruebas';
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Concurrencia: editar con RowVersion desactualizado', 54001, 0, N'No hubo error');
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Concurrencia: editar con RowVersion desactualizado', 54001, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH

BEGIN TRY
    SET @rv = (SELECT RowVersion FROM compras.Proveedores WHERE IdProveedor = @prv7);
    EXEC compras.sp_Proveedor_Actualizar @IdProveedor = @prv7, @Nombre = N'Editar inactivo', @Nit = '3216549-8',
         @IdCategoria = @catAbarrotes, @TipoPago = 'Contado', @RowVersion = @rv, @Usuario = N'pruebas';
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'No se edita un proveedor inactivo', 53003, 0, N'No hubo error');
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'No se edita un proveedor inactivo', 53003, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH

BEGIN TRY
    EXEC compras.sp_Proveedor_Inactivar @IdProveedor = @prv1, @Motivo = N'corto', @Usuario = N'pruebas';
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Inactivar exige motivo de 10+ caracteres', 51017, 0, N'No hubo error');
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Inactivar exige motivo de 10+ caracteres', 51017, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH

BEGIN TRY
    EXEC compras.sp_Proveedor_Inactivar @IdProveedor = @prv2, @Motivo = N'Prueba de inactivación con órdenes abiertas', @Usuario = N'pruebas';
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'No se inactiva proveedor con órdenes abiertas', 53005, 0, N'No hubo error');
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'No se inactiva proveedor con órdenes abiertas', 53005, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH

BEGIN TRY
    DELETE FROM compras.Proveedores WHERE IdProveedor = @prv7;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Trigger: prohíbe DELETE físico de proveedores', 53001, 0, N'No hubo error');
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Trigger: prohíbe DELETE físico de proveedores', 53001, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH

/* ---------------------------- ÓRDENES DE COMPRA ---------------------------- */
SET @det = CONCAT(N'[{"idProducto":', @a1, N',"cantidad":10,"costoUnitario":4.25}]');

BEGIN TRY
    EXEC compras.sp_OrdenCompra_Crear @IdProveedor = @prv7, @IdBodega = @b1, @FechaEsperada = @hoy,
         @Detalle = @det, @Usuario = N'pruebas', @IdOrdenCompra = @id OUTPUT;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Proveedor inactivo no recibe órdenes', 53006, 0, N'No hubo error');
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Proveedor inactivo no recibe órdenes', 53006, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH

BEGIN TRY
    EXEC compras.sp_OrdenCompra_Crear @IdProveedor = @prv1, @IdBodega = @b1, @FechaOrden = @hoy, @FechaEsperada = @ayer,
         @Detalle = @det, @Usuario = N'pruebas', @IdOrdenCompra = @id OUTPUT;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Fecha esperada anterior a la orden', 51024, 0, N'No hubo error');
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Fecha esperada anterior a la orden', 51024, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH

BEGIN TRY
    EXEC compras.sp_OrdenCompra_Crear @IdProveedor = @prv1, @IdBodega = @b1, @FechaEsperada = @hoy,
         @Detalle = N'[]', @Usuario = N'pruebas', @IdOrdenCompra = @id OUTPUT;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Orden sin líneas', 51020, 0, N'No hubo error');
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Orden sin líneas', 51020, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH

BEGIN TRY
    SET @det = CONCAT(N'[{"idProducto":', @a1, N',"cantidad":10,"costoUnitario":4.25},{"idProducto":', @a1, N',"cantidad":5,"costoUnitario":4.25}]');
    EXEC compras.sp_OrdenCompra_Crear @IdProveedor = @prv1, @IdBodega = @b1, @FechaEsperada = @hoy,
         @Detalle = @det, @Usuario = N'pruebas', @IdOrdenCompra = @id OUTPUT;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Producto repetido en la orden', 51023, 0, N'No hubo error');
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Producto repetido en la orden', 51023, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH

BEGIN TRY
    SET @det = CONCAT(N'[{"idProducto":', @a1, N',"cantidad":-3,"costoUnitario":4.25}]');
    EXEC compras.sp_OrdenCompra_Crear @IdProveedor = @prv1, @IdBodega = @b1, @FechaEsperada = @hoy,
         @Detalle = @det, @Usuario = N'pruebas', @IdOrdenCompra = @id OUTPUT;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Cantidad negativa', 51022, 0, N'No hubo error');
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Cantidad negativa', 51022, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH

BEGIN TRY
    SET @det = CONCAT(N'[{"idProducto":', @a1, N',"cantidad":10,"costoUnitario":4.25}]');
    SET @rv = (SELECT RowVersion FROM compras.OrdenesCompra WHERE IdOrdenCompra = @ocAprobada);
    EXEC compras.sp_OrdenCompra_Actualizar @IdOrdenCompra = @ocAprobada, @IdProveedor = @prv1, @IdBodega = @b1,
         @FechaEsperada = @hoy, @Detalle = @det, @RowVersion = @rv, @Usuario = N'pruebas';
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Editar orden ya aprobada', 53007, 0, N'No hubo error');
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Editar orden ya aprobada', 53007, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH

BEGIN TRY
    EXEC compras.sp_OrdenCompra_Aprobar @IdOrdenCompra = @ocPendiente, @Usuario = N'sara.compras';
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Quien crea la orden no puede aprobarla', 53017, 0, N'No hubo error');
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Quien crea la orden no puede aprobarla', 53017, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH

BEGIN TRY
    EXEC compras.sp_OrdenCompra_Anular @IdOrdenCompra = @ocParcial, @Motivo = N'Prueba de anulación con recepciones', @Usuario = N'pruebas';
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'No se anula orden con recepciones', 53012, 0, N'No hubo error');
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'No se anula orden con recepciones', 53012, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH

BEGIN TRY
    UPDATE compras.OrdenesCompra SET Estado = 'Pendiente' WHERE IdOrdenCompra = @ocAprobada;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Trigger: retroceso de estado Aprobada -> Pendiente', 53010, 0, N'No hubo error');
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Trigger: retroceso de estado Aprobada -> Pendiente', 53010, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH

/* ------------------------------- RECEPCIONES ------------------------------- */
BEGIN TRY
    SET @rec = (SELECT IdDetalle AS idDetalle, CantidadPedida AS cantidad FROM compras.OrdenesCompraDetalle
                WHERE IdOrdenCompra = @ocPendiente FOR JSON PATH);
    EXEC compras.sp_Recepcion_Registrar @IdOrdenCompra = @ocPendiente, @NumeroFactura = 'T-1',
         @Detalle = @rec, @Usuario = N'pruebas', @IdRecepcion = @id OUTPUT;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'No se recibe una orden sin aprobar', 53009, 0, N'No hubo error');
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'No se recibe una orden sin aprobar', 53009, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH

BEGIN TRY
    SET @rec = (SELECT IdDetalle AS idDetalle, CantidadPedida + 1000 AS cantidad FROM compras.OrdenesCompraDetalle
                WHERE IdOrdenCompra = @ocAtrasada FOR JSON PATH);
    EXEC compras.sp_Recepcion_Registrar @IdOrdenCompra = @ocAtrasada, @NumeroFactura = 'T-2',
         @Detalle = @rec, @Usuario = N'pruebas', @IdRecepcion = @id OUTPUT;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Recibir más de lo pendiente', 51030, 0, N'No hubo error');
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Recibir más de lo pendiente', 51030, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH

BEGIN TRY
    SET @rec = (SELECT IdDetalle AS idDetalle, 1 AS cantidad FROM compras.OrdenesCompraDetalle
                WHERE IdOrdenCompra = @ocAtrasada FOR JSON PATH);
    EXEC compras.sp_Recepcion_Registrar @IdOrdenCompra = @ocAtrasada, @SerieFactura = 'B', @NumeroFactura = '2001',
         @Detalle = @rec, @Usuario = N'pruebas', @IdRecepcion = @id OUTPUT;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Factura del proveedor duplicada', 53011, 0, N'No hubo error');
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Factura del proveedor duplicada', 53011, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH

BEGIN TRY
    UPDATE compras.Recepciones SET Total = Total + 1 WHERE IdRecepcion = @recep;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Trigger: la nota de compra no se modifica', 53016, 0, N'No hubo error');
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Trigger: la nota de compra no se modifica', 53016, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH

/* ------------------------------ PAGOS Y SALDOS ------------------------------ */
BEGIN TRY
    SET @op = NEWID();
    EXEC compras.sp_Pago_Iniciar @IdCuentaPagar = @cxpAbierta, @OperacionId = @op, @Monto = 999999.00,
         @Metodo = 'Efectivo', @Usuario = N'pruebas', @IdPago = @id OUTPUT;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Pago mayor al saldo', 53013, 0, N'No hubo error');
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Pago mayor al saldo', 53013, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH

BEGIN TRY
    SET @op = NEWID();
    EXEC compras.sp_Pago_Iniciar @IdCuentaPagar = @cxpAbierta, @OperacionId = @op, @Monto = 10.00,
         @Metodo = 'Cheque', @Usuario = N'pruebas', @IdPago = @id OUTPUT;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Cheque sin número', 51041, 0, N'No hubo error');
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Cheque sin número', 51041, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH

BEGIN TRY
    UPDATE compras.CuentasPorPagar SET Monto = Monto + 100 WHERE IdCuentaPagar = @cxpAbierta;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Trigger: el monto de la cuenta por pagar no cambia', 53019, 0, N'No hubo error');
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Trigger: el monto de la cuenta por pagar no cambia', 53019, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH

/* ------------------------------ AUDITORÍA / REPORTES ------------------------------ */
BEGIN TRY
    DELETE FROM aud.Bitacora WHERE IdBitacora = (SELECT MIN(IdBitacora) FROM aud.Bitacora);
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Trigger: la bitácora no se borra', 53001, 0, N'No hubo error');
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Trigger: la bitácora no se borra', 53001, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH

BEGIN TRY
    EXEC rpt.sp_ComprasPorProveedor @FechaDesde = @hoy, @FechaHasta = @ayer;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Reporte con rango de fechas invertido', 51050, 0, N'No hubo error');
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK;
    INSERT @r (Prueba, Esperado, Obtenido, Mensaje) VALUES (N'Reporte con rango de fechas invertido', 51050, ERROR_NUMBER(), ERROR_MESSAGE());
END CATCH

/* -------------------------------- RESULTADOS -------------------------------- */
SELECT N, Prueba, Esperado, Obtenido,
       CASE WHEN Esperado = Obtenido THEN N'PASÓ' ELSE N'FALLÓ' END AS Resultado,
       Mensaje
FROM @r
ORDER BY N;

SELECT COUNT(*) AS TotalPruebas,
       SUM(CASE WHEN Esperado = Obtenido THEN 1 ELSE 0 END) AS Pasaron,
       SUM(CASE WHEN Esperado <> Obtenido THEN 1 ELSE 0 END) AS Fallaron
FROM @r;
GO

/* Verificaciones de integridad (todas deben devolver 0 filas) */
SELECT N'Orden con total distinto a la suma de sus líneas' AS Problema, o.Numero
FROM compras.OrdenesCompra AS o
CROSS APPLY (SELECT SUM(Subtotal) AS S FROM compras.OrdenesCompraDetalle WHERE IdOrdenCompra = o.IdOrdenCompra) AS d
WHERE o.Subtotal <> ISNULL(d.S, 0)
UNION ALL
SELECT N'Cuenta con saldo distinto a monto - pagos aprobados', c.Numero
FROM compras.CuentasPorPagar AS c
CROSS APPLY (SELECT ISNULL(SUM(Monto), 0) AS P FROM compras.PagosProveedor WHERE IdCuentaPagar = c.IdCuentaPagar AND Estado = 'Aprobado') AS p
WHERE c.Saldo <> c.Monto - p.P
UNION ALL
SELECT N'Recepción sin cuenta por pagar', r.Numero
FROM compras.Recepciones AS r
WHERE NOT EXISTS (SELECT 1 FROM compras.CuentasPorPagar AS c WHERE c.IdRecepcion = r.IdRecepcion)
UNION ALL
SELECT N'Recepción sin movimiento de kardex', r.Numero
FROM compras.Recepciones AS r
WHERE NOT EXISTS (SELECT 1 FROM inv.MovimientosInventario AS m
                  WHERE m.DocumentoOrigen = 'RECEPCION_COMPRA' AND m.IdDocumento = r.IdRecepcion);
GO
