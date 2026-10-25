/* =====================================================================
   LA PROMESA ERP  |  09 - Procedimientos: ÓRDENES DE COMPRA y RECEPCIONES
   ---------------------------------------------------------------------
   CRUD completo de Compras:
     Listar | Obtener | Crear | Actualizar (solo Pendiente) | Aprobar |
     Anular (con motivo, sin recepciones) | Recibir (parcial o total)
   El detalle llega como JSON desde la API, por ejemplo:
     Orden    : [{"idProducto":1,"cantidad":10,"costoUnitario":4.25}]
     Recepción: [{"idDetalle":1,"cantidad":5}]
   El total SIEMPRE lo calcula la base de datos (nunca el frontend).
   ===================================================================== */
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
USE LaPromesaERP;
GO

/* ================ VALIDAR Y CARGAR LÍNEAS DE LA ORDEN ================
   El procedimiento que llama debe crear antes:
     CREATE TABLE #Lineas (IdProducto INT, Cantidad DECIMAL(18,2), CostoUnitario DECIMAL(18,4));
   ===================================================================== */
CREATE OR ALTER PROCEDURE compras.sp_OrdenCompra_CargarDetalle
    @Detalle NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @maxLineas INT = ISNULL(TRY_CAST(cfg.fn_Parametro('OC_MAX_LINEAS') AS INT), 100);
    DECLARE @msg NVARCHAR(300);

    IF @Detalle IS NULL OR ISJSON(@Detalle) = 0 OR LEFT(LTRIM(@Detalle), 1) <> N'['
        THROW 51020, N'El detalle debe ser un arreglo JSON de líneas.', 1;

    INSERT INTO #Lineas (IdProducto, Cantidad, CostoUnitario)
    SELECT TRY_CAST(j.IdProducto AS INT), TRY_CAST(j.Cantidad AS DECIMAL(18,2)), TRY_CAST(j.CostoUnitario AS DECIMAL(18,4))
    FROM OPENJSON(@Detalle)
         WITH (IdProducto    NVARCHAR(50) '$.idProducto',
               Cantidad      NVARCHAR(50) '$.cantidad',
               CostoUnitario NVARCHAR(50) '$.costoUnitario') AS j;

    DECLARE @n INT = (SELECT COUNT(*) FROM #Lineas);
    IF @n = 0
        THROW 51020, N'La orden debe tener al menos una línea.', 1;
    IF @n > @maxLineas
    BEGIN
        SET @msg = CONCAT(N'La orden no puede tener más de ', @maxLineas, N' líneas.');
        THROW 51020, @msg, 1;
    END
    IF EXISTS (SELECT 1 FROM #Lineas WHERE IdProducto IS NULL OR Cantidad IS NULL OR CostoUnitario IS NULL)
        THROW 51020, N'Cada línea requiere idProducto, cantidad y costoUnitario numéricos.', 1;
    IF EXISTS (SELECT 1 FROM #Lineas WHERE Cantidad <= 0 OR CostoUnitario <= 0)
        THROW 51022, N'La cantidad y el costo unitario deben ser mayores que cero.', 1;
    IF EXISTS (SELECT IdProducto FROM #Lineas GROUP BY IdProducto HAVING COUNT(*) > 1)
        THROW 51023, N'Un producto no puede repetirse en la misma orden; sume las cantidades en una sola línea.', 1;
    IF EXISTS (SELECT 1 FROM #Lineas AS l
               LEFT JOIN inv.Productos AS p ON p.IdProducto = l.IdProducto AND p.Activo = 1
               WHERE p.IdProducto IS NULL)
        THROW 51021, N'Uno o más productos no existen o están inactivos.', 1;
END
GO

/* =============================== LISTAR =============================== */
CREATE OR ALTER PROCEDURE compras.sp_OrdenCompra_Listar
    @Buscar        NVARCHAR(100) = NULL,   -- número de orden o nombre/NIT del proveedor
    @Estado        VARCHAR(10)   = NULL,
    @IdProveedor   INT           = NULL,
    @IdBodega      INT           = NULL,
    @FechaDesde    DATE          = NULL,
    @FechaHasta    DATE          = NULL,
    @SoloAtrasadas BIT           = 0,
    @OrdenarPor    VARCHAR(20)   = 'FechaOrden',
    @Direccion     VARCHAR(4)    = 'DESC',
    @Pagina        INT           = 1,
    @TamanoPagina  INT           = 10
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @Pagina < 1 OR @TamanoPagina NOT BETWEEN 1 AND 100
            THROW 51000, N'Paginación inválida: página >= 1 y tamaño entre 1 y 100.', 1;
        IF @OrdenarPor NOT IN ('Numero', 'Proveedor', 'FechaOrden', 'FechaEsperada', 'Total', 'Estado')
            THROW 51000, N'Campo de ordenamiento no permitido.', 1;
        IF @Direccion NOT IN ('ASC', 'DESC')
            THROW 51000, N'La dirección de ordenamiento debe ser ASC o DESC.', 1;
        IF @Estado IS NOT NULL AND @Estado NOT IN ('Pendiente', 'Aprobada', 'Parcial', 'Recibida', 'Anulada')
            THROW 51000, N'Filtro de estado inválido.', 1;
        IF @FechaDesde IS NOT NULL AND @FechaHasta IS NOT NULL AND @FechaDesde > @FechaHasta
            THROW 51024, N'La fecha inicial no puede ser mayor que la fecha final.', 1;

        DECLARE @b NVARCHAR(110) = NULLIF(LTRIM(RTRIM(@Buscar)), N'');
        SET @b = REPLACE(REPLACE(REPLACE(@b, N'[', N'[[]'), N'%', N'[%]'), N'_', N'[_]');

        SELECT
            v.IdOrdenCompra, v.Numero, v.IdProveedor, v.CodigoProveedor, v.Proveedor, v.NitProveedor,
            v.IdBodega, v.Bodega, v.FechaOrden, v.FechaEsperada, v.TipoPago, v.DiasCredito,
            v.Subtotal, v.Iva, v.Total, v.Estado, v.Lineas, v.PorcentajeRecibido, v.Recepciones,
            v.DiasParaEntrega, v.EstaAtrasada, v.CreadoPor, v.AprobadoPor, v.RowVersion,
            COUNT(*) OVER () AS TotalRegistros
        FROM compras.vw_OrdenesCompra AS v
        WHERE (@b IS NULL OR v.Numero LIKE N'%' + @b + N'%'
                          OR v.Proveedor LIKE N'%' + @b + N'%'
                          OR v.NitProveedor LIKE N'%' + @b + N'%')
          AND (@Estado      IS NULL OR v.Estado      = @Estado)
          AND (@IdProveedor IS NULL OR v.IdProveedor = @IdProveedor)
          AND (@IdBodega    IS NULL OR v.IdBodega    = @IdBodega)
          AND (@FechaDesde  IS NULL OR v.FechaOrden >= @FechaDesde)
          AND (@FechaHasta  IS NULL OR v.FechaOrden <= @FechaHasta)
          AND (@SoloAtrasadas = 0 OR v.EstaAtrasada = 1)
        ORDER BY
            CASE WHEN @Direccion = 'ASC'  AND @OrdenarPor = 'Numero'        THEN v.Numero        END ASC,
            CASE WHEN @Direccion = 'DESC' AND @OrdenarPor = 'Numero'        THEN v.Numero        END DESC,
            CASE WHEN @Direccion = 'ASC'  AND @OrdenarPor = 'Proveedor'     THEN v.Proveedor     END ASC,
            CASE WHEN @Direccion = 'DESC' AND @OrdenarPor = 'Proveedor'     THEN v.Proveedor     END DESC,
            CASE WHEN @Direccion = 'ASC'  AND @OrdenarPor = 'FechaOrden'    THEN v.FechaOrden    END ASC,
            CASE WHEN @Direccion = 'DESC' AND @OrdenarPor = 'FechaOrden'    THEN v.FechaOrden    END DESC,
            CASE WHEN @Direccion = 'ASC'  AND @OrdenarPor = 'FechaEsperada' THEN v.FechaEsperada END ASC,
            CASE WHEN @Direccion = 'DESC' AND @OrdenarPor = 'FechaEsperada' THEN v.FechaEsperada END DESC,
            CASE WHEN @Direccion = 'ASC'  AND @OrdenarPor = 'Total'         THEN v.Total         END ASC,
            CASE WHEN @Direccion = 'DESC' AND @OrdenarPor = 'Total'         THEN v.Total         END DESC,
            CASE WHEN @Direccion = 'ASC'  AND @OrdenarPor = 'Estado'        THEN v.Estado        END ASC,
            CASE WHEN @Direccion = 'DESC' AND @OrdenarPor = 'Estado'        THEN v.Estado        END DESC,
            v.IdOrdenCompra DESC
        OFFSET (@Pagina - 1) * @TamanoPagina ROWS
        FETCH NEXT @TamanoPagina ROWS ONLY
        OPTION (RECOMPILE);
    END TRY
    BEGIN CATCH
        EXEC aud.sp_RegistrarError @Procedimiento = N'compras.sp_OrdenCompra_Listar';
        THROW;
    END CATCH
END
GO

/* ==================== OBTENER (encabezado + detalle) ====================
   Resultado 1: orden | 2: líneas | 3: recepciones | 4: historial         */
CREATE OR ALTER PROCEDURE compras.sp_OrdenCompra_Obtener
    @IdOrdenCompra INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM compras.OrdenesCompra WHERE IdOrdenCompra = @IdOrdenCompra)
            THROW 52002, N'La orden de compra no existe.', 1;

        SELECT * FROM compras.vw_OrdenesCompra WHERE IdOrdenCompra = @IdOrdenCompra;

        SELECT * FROM compras.vw_OrdenesCompraDetalle WHERE IdOrdenCompra = @IdOrdenCompra ORDER BY IdDetalle;

        SELECT IdRecepcion, Numero, FechaRecepcion, Factura, Cumplimiento, DiasDiferencia, Total, RecibidoPor,
               IdCuentaPagar, NumeroCuentaPagar
        FROM compras.vw_Recepciones WHERE IdOrdenCompra = @IdOrdenCompra ORDER BY FechaRecepcion, IdRecepcion;

        SELECT EstadoAnterior, EstadoNuevo, Fecha, Usuario, Comentario
        FROM compras.OrdenesCompraHistorial WHERE IdOrdenCompra = @IdOrdenCompra ORDER BY Fecha, IdHistorial;
    END TRY
    BEGIN CATCH
        EXEC aud.sp_RegistrarError @Procedimiento = N'compras.sp_OrdenCompra_Obtener';
        THROW;
    END CATCH
END
GO

/* ================================ CREAR ================================ */
CREATE OR ALTER PROCEDURE compras.sp_OrdenCompra_Crear
    @IdProveedor    INT,
    @IdBodega       INT,
    @FechaOrden     DATE          = NULL,   -- NULL = hoy
    @FechaEsperada  DATE,
    @Observaciones  NVARCHAR(300) = NULL,
    @Detalle        NVARCHAR(MAX),
    @Usuario        NVARCHAR(100),
    @IdOrdenCompra  INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF NULLIF(LTRIM(RTRIM(@Usuario)), N'') IS NULL
            THROW 51001, N'El usuario que realiza la operación es obligatorio.', 1;

        DECLARE @hoy DATE = CAST(GETDATE() AS DATE);
        SET @FechaOrden = ISNULL(@FechaOrden, @hoy);

        IF @FechaOrden > @hoy
            THROW 51024, N'La fecha de la orden no puede ser futura.', 1;
        IF @FechaEsperada IS NULL OR @FechaEsperada < @FechaOrden
            THROW 51024, N'La fecha esperada de entrega debe ser igual o posterior a la fecha de la orden.', 1;

        DECLARE @estadoProv VARCHAR(10), @tipoPago VARCHAR(10), @dias INT, @sec BIGINT;
        SELECT @estadoProv = Estado, @tipoPago = TipoPago, @dias = DiasCredito
        FROM compras.Proveedores WHERE IdProveedor = @IdProveedor;

        IF @estadoProv IS NULL      THROW 52001, N'El proveedor no existe.', 1;
        IF @estadoProv <> 'Activo'  THROW 53006, N'Un proveedor inactivo no puede recibir nuevas órdenes de compra.', 1;
        IF NOT EXISTS (SELECT 1 FROM inv.Bodegas WHERE IdBodega = @IdBodega AND Activo = 1)
            THROW 51025, N'La bodega no existe o no está activa.', 1;

        CREATE TABLE #Lineas (IdProducto INT, Cantidad DECIMAL(18,2), CostoUnitario DECIMAL(18,4));
        EXEC compras.sp_OrdenCompra_CargarDetalle @Detalle = @Detalle;

        DECLARE @tasa DECIMAL(5,4) = ISNULL(TRY_CAST(cfg.fn_Parametro('TASA_IVA') AS DECIMAL(5,4)), 0.12);

        EXEC sys.sp_set_session_context @key = N'usuario', @value = @Usuario;

        BEGIN TRANSACTION;
            SET @sec = NEXT VALUE FOR compras.seq_OrdenCompra;

            INSERT INTO compras.OrdenesCompra
                (Numero, IdProveedor, IdBodega, FechaOrden, FechaEsperada, TipoPago, DiasCredito,
                 Observaciones, TasaIva, Estado, CreadoPor)
            VALUES
                (compras.fn_FormatearNumero('OC-', @sec, 6), @IdProveedor, @IdBodega, @FechaOrden, @FechaEsperada,
                 @tipoPago, @dias, NULLIF(LTRIM(RTRIM(@Observaciones)), N''), @tasa, 'Pendiente', @Usuario);

            SET @IdOrdenCompra = SCOPE_IDENTITY();

            INSERT INTO compras.OrdenesCompraDetalle (IdOrdenCompra, IdProducto, CantidadPedida, CostoUnitario)
            SELECT @IdOrdenCompra, IdProducto, Cantidad, CostoUnitario
            FROM #Lineas;
        COMMIT TRANSACTION;

        SELECT * FROM compras.vw_OrdenesCompra WHERE IdOrdenCompra = @IdOrdenCompra;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        EXEC aud.sp_RegistrarError @Procedimiento = N'compras.sp_OrdenCompra_Crear', @Parametros = @Detalle;
        THROW;
    END CATCH
END
GO

/* ===================== ACTUALIZAR (solo Pendiente) ===================== */
CREATE OR ALTER PROCEDURE compras.sp_OrdenCompra_Actualizar
    @IdOrdenCompra  INT,
    @IdProveedor    INT,
    @IdBodega       INT,
    @FechaEsperada  DATE,
    @Observaciones  NVARCHAR(300) = NULL,
    @Detalle        NVARCHAR(MAX),
    @RowVersion     BINARY(8),
    @Usuario        NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF NULLIF(LTRIM(RTRIM(@Usuario)), N'') IS NULL
            THROW 51001, N'El usuario que realiza la operación es obligatorio.', 1;
        IF @RowVersion IS NULL
            THROW 51002, N'Se requiere la versión del registro (RowVersion) para actualizar.', 1;
        IF NOT EXISTS (SELECT 1 FROM compras.OrdenesCompra WHERE IdOrdenCompra = @IdOrdenCompra)
            THROW 52002, N'La orden de compra no existe.', 1;

        DECLARE @estadoProv VARCHAR(10), @tipoPago VARCHAR(10), @dias INT;
        SELECT @estadoProv = Estado, @tipoPago = TipoPago, @dias = DiasCredito
        FROM compras.Proveedores WHERE IdProveedor = @IdProveedor;

        IF @estadoProv IS NULL      THROW 52001, N'El proveedor no existe.', 1;
        IF @estadoProv <> 'Activo'  THROW 53006, N'Un proveedor inactivo no puede recibir nuevas órdenes de compra.', 1;
        IF NOT EXISTS (SELECT 1 FROM inv.Bodegas WHERE IdBodega = @IdBodega AND Activo = 1)
            THROW 51025, N'La bodega no existe o no está activa.', 1;

        CREATE TABLE #Lineas (IdProducto INT, Cantidad DECIMAL(18,2), CostoUnitario DECIMAL(18,4));
        EXEC compras.sp_OrdenCompra_CargarDetalle @Detalle = @Detalle;

        EXEC sys.sp_set_session_context @key = N'usuario', @value = @Usuario;

        BEGIN TRANSACTION;
            DECLARE @estado VARCHAR(10), @rv BINARY(8), @fechaOrden DATE;
            SELECT @estado = Estado, @rv = RowVersion, @fechaOrden = FechaOrden
            FROM compras.OrdenesCompra WITH (UPDLOCK, HOLDLOCK)
            WHERE IdOrdenCompra = @IdOrdenCompra;

            IF @rv <> @RowVersion
                THROW 54001, N'La orden fue modificada por otro usuario. Recargue los datos e intente de nuevo.', 1;
            IF @estado <> 'Pendiente'
                THROW 53007, N'Solo se pueden editar órdenes en estado Pendiente.', 1;
            IF @FechaEsperada IS NULL OR @FechaEsperada < @fechaOrden
                THROW 51024, N'La fecha esperada de entrega debe ser igual o posterior a la fecha de la orden.', 1;

            UPDATE compras.OrdenesCompra
               SET IdProveedor       = @IdProveedor,
                   IdBodega          = @IdBodega,
                   FechaEsperada     = @FechaEsperada,
                   TipoPago          = @tipoPago,
                   DiasCredito       = @dias,
                   Observaciones     = NULLIF(LTRIM(RTRIM(@Observaciones)), N''),
                   FechaModificacion = SYSDATETIME(),
                   ModificadoPor     = @Usuario
             WHERE IdOrdenCompra = @IdOrdenCompra;

            -- Sincronizar líneas: actualizar existentes, quitar las que ya no vienen, agregar nuevas
            UPDATE d
               SET CantidadPedida = l.Cantidad,
                   CostoUnitario  = l.CostoUnitario
            FROM compras.OrdenesCompraDetalle AS d
            INNER JOIN #Lineas AS l ON l.IdProducto = d.IdProducto
            WHERE d.IdOrdenCompra = @IdOrdenCompra
              AND (d.CantidadPedida <> l.Cantidad OR d.CostoUnitario <> l.CostoUnitario);

            DELETE d
            FROM compras.OrdenesCompraDetalle AS d
            WHERE d.IdOrdenCompra = @IdOrdenCompra
              AND NOT EXISTS (SELECT 1 FROM #Lineas AS l WHERE l.IdProducto = d.IdProducto);

            INSERT INTO compras.OrdenesCompraDetalle (IdOrdenCompra, IdProducto, CantidadPedida, CostoUnitario)
            SELECT @IdOrdenCompra, l.IdProducto, l.Cantidad, l.CostoUnitario
            FROM #Lineas AS l
            WHERE NOT EXISTS (SELECT 1 FROM compras.OrdenesCompraDetalle AS d
                              WHERE d.IdOrdenCompra = @IdOrdenCompra AND d.IdProducto = l.IdProducto);
        COMMIT TRANSACTION;

        SELECT * FROM compras.vw_OrdenesCompra WHERE IdOrdenCompra = @IdOrdenCompra;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        EXEC aud.sp_RegistrarError @Procedimiento = N'compras.sp_OrdenCompra_Actualizar', @Parametros = @Detalle;
        THROW;
    END CATCH
END
GO

/* =============================== APROBAR ===============================
   - Solo órdenes Pendiente.
   - Segregación de funciones: quien crea no aprueba (parámetro).
   - Control de límite de crédito del proveedor.                          */
CREATE OR ALTER PROCEDURE compras.sp_OrdenCompra_Aprobar
    @IdOrdenCompra  INT,
    @RowVersion     BINARY(8) = NULL,
    @Usuario        NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF NULLIF(LTRIM(RTRIM(@Usuario)), N'') IS NULL
            THROW 51001, N'El usuario que realiza la operación es obligatorio.', 1;

        DECLARE @estado VARCHAR(10), @rv BINARY(8), @creadoPor NVARCHAR(100), @idProv INT, @total DECIMAL(18,2);
        DECLARE @limite DECIMAL(18,2), @estadoProv VARCHAR(10), @comprometido DECIMAL(18,2), @msg NVARCHAR(400);

        EXEC sys.sp_set_session_context @key = N'usuario', @value = @Usuario;

        BEGIN TRANSACTION;
            SELECT @estado = Estado, @rv = RowVersion, @creadoPor = CreadoPor, @idProv = IdProveedor, @total = Total
            FROM compras.OrdenesCompra WITH (UPDLOCK, HOLDLOCK)
            WHERE IdOrdenCompra = @IdOrdenCompra;

            IF @estado IS NULL THROW 52002, N'La orden de compra no existe.', 1;
            IF @RowVersion IS NOT NULL AND @rv <> @RowVersion
                THROW 54001, N'La orden fue modificada por otro usuario. Recargue los datos e intente de nuevo.', 1;
            IF @estado <> 'Pendiente'
                THROW 53010, N'Solo se pueden aprobar órdenes en estado Pendiente.', 1;
            IF cfg.fn_Parametro('OC_APROBADOR_DISTINTO') = N'1' AND @creadoPor = @Usuario
                THROW 53017, N'Quien creó la orden no puede aprobarla (segregación de funciones).', 1;
            IF @total <= 0
                THROW 51020, N'La orden no tiene líneas con valor.', 1;

            SELECT @estadoProv = Estado, @limite = LimiteCredito
            FROM compras.Proveedores WHERE IdProveedor = @idProv;

            IF @estadoProv <> 'Activo'
                THROW 53006, N'Un proveedor inactivo no puede recibir nuevas órdenes de compra.', 1;

            IF @limite > 0
            BEGIN
                -- Saldo por pagar + lo aprobado pendiente de recibir + esta orden
                SELECT @comprometido =
                      ISNULL((SELECT SUM(Saldo) FROM compras.CuentasPorPagar
                              WHERE IdProveedor = @idProv AND Estado <> 'Pagada'), 0)
                    + ISNULL((SELECT SUM(ROUND((d.CantidadPedida - d.CantidadRecibida) * d.CostoUnitario * (1 + o.TasaIva), 2))
                              FROM compras.OrdenesCompra AS o
                              INNER JOIN compras.OrdenesCompraDetalle AS d ON d.IdOrdenCompra = o.IdOrdenCompra
                              WHERE o.IdProveedor = @idProv AND o.Estado IN ('Aprobada', 'Parcial')), 0)
                    + @total;

                IF @comprometido > @limite
                BEGIN
                    SET @msg = CONCAT(N'La orden excede el límite de crédito del proveedor. Límite: Q', FORMAT(@limite, 'N2'),
                                      N'; comprometido con esta orden: Q', FORMAT(@comprometido, 'N2'), N'.');
                    THROW 53008, @msg, 1;
                END
            END

            UPDATE compras.OrdenesCompra
               SET Estado            = 'Aprobada',
                   FechaAprobacion   = SYSDATETIME(),
                   AprobadoPor       = @Usuario,
                   FechaModificacion = SYSDATETIME(),
                   ModificadoPor     = @Usuario
             WHERE IdOrdenCompra = @IdOrdenCompra;
        COMMIT TRANSACTION;

        SELECT * FROM compras.vw_OrdenesCompra WHERE IdOrdenCompra = @IdOrdenCompra;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        EXEC aud.sp_RegistrarError @Procedimiento = N'compras.sp_OrdenCompra_Aprobar';
        THROW;
    END CATCH
END
GO

/* =============================== ANULAR =============================== */
CREATE OR ALTER PROCEDURE compras.sp_OrdenCompra_Anular
    @IdOrdenCompra  INT,
    @Motivo         NVARCHAR(250),
    @RowVersion     BINARY(8) = NULL,
    @Usuario        NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF NULLIF(LTRIM(RTRIM(@Usuario)), N'') IS NULL
            THROW 51001, N'El usuario que realiza la operación es obligatorio.', 1;
        SET @Motivo = NULLIF(LTRIM(RTRIM(@Motivo)), N'');
        IF @Motivo IS NULL OR LEN(@Motivo) < 10
            THROW 51017, N'El motivo de anulación es obligatorio (mínimo 10 caracteres).', 1;

        DECLARE @estado VARCHAR(10), @rv BINARY(8);

        EXEC sys.sp_set_session_context @key = N'usuario', @value = @Usuario;

        BEGIN TRANSACTION;
            SELECT @estado = Estado, @rv = RowVersion
            FROM compras.OrdenesCompra WITH (UPDLOCK, HOLDLOCK)
            WHERE IdOrdenCompra = @IdOrdenCompra;

            IF @estado IS NULL THROW 52002, N'La orden de compra no existe.', 1;
            IF @RowVersion IS NOT NULL AND @rv <> @RowVersion
                THROW 54001, N'La orden fue modificada por otro usuario. Recargue los datos e intente de nuevo.', 1;
            IF @estado IN ('Recibida', 'Anulada')
                THROW 53019, N'La orden de compra está en un estado final (Recibida o Anulada) y no puede anularse.', 1;
            IF EXISTS (SELECT 1 FROM compras.Recepciones WHERE IdOrdenCompra = @IdOrdenCompra)
                THROW 53012, N'No se puede anular una orden que ya tiene recepciones registradas.', 1;

            UPDATE compras.OrdenesCompra
               SET Estado            = 'Anulada',
                   FechaAnulacion    = SYSDATETIME(),
                   AnuladoPor        = @Usuario,
                   MotivoAnulacion   = @Motivo,
                   FechaModificacion = SYSDATETIME(),
                   ModificadoPor     = @Usuario
             WHERE IdOrdenCompra = @IdOrdenCompra;
        COMMIT TRANSACTION;

        SELECT * FROM compras.vw_OrdenesCompra WHERE IdOrdenCompra = @IdOrdenCompra;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        EXEC aud.sp_RegistrarError @Procedimiento = N'compras.sp_OrdenCompra_Anular';
        THROW;
    END CATCH
END
GO

/* ======================== REGISTRAR RECEPCIÓN ========================
   PROCESO INTEGRADO (una sola transacción, todo o nada):
     1. Valida la orden (Aprobada/Parcial), factura y cantidades.
     2. Crea la nota de compra (recepción) con cumplimiento RQ27.
     3. Aumenta la cantidad recibida de cada línea.
     4. INVENTARIO: costo promedio, existencias y kardex (temporal).
     5. Cambia la orden a Parcial o Recibida.
     6. Genera la cuenta por pagar con vencimiento según días de crédito.
   ===================================================================== */
CREATE OR ALTER PROCEDURE compras.sp_Recepcion_Registrar
    @IdOrdenCompra   INT,
    @FechaRecepcion  DATE          = NULL,   -- NULL = hoy
    @SerieFactura    VARCHAR(20)   = NULL,
    @NumeroFactura   VARCHAR(30),
    @Observaciones   NVARCHAR(300) = NULL,
    @Detalle         NVARCHAR(MAX),
    @Usuario         NVARCHAR(100),
    @IdRecepcion     INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF NULLIF(LTRIM(RTRIM(@Usuario)), N'') IS NULL
            THROW 51001, N'El usuario que realiza la operación es obligatorio.', 1;

        DECLARE @hoy DATE = CAST(GETDATE() AS DATE);
        SET @FechaRecepcion = ISNULL(@FechaRecepcion, @hoy);
        SET @NumeroFactura  = NULLIF(UPPER(LTRIM(RTRIM(@NumeroFactura))), '');
        SET @SerieFactura   = NULLIF(UPPER(LTRIM(RTRIM(@SerieFactura))), '');

        IF @FechaRecepcion > @hoy
            THROW 51024, N'La fecha de recepción no puede ser futura.', 1;
        IF @NumeroFactura IS NULL
            THROW 51032, N'El número de factura del proveedor es obligatorio.', 1;
        IF @Detalle IS NULL OR ISJSON(@Detalle) = 0 OR LEFT(LTRIM(@Detalle), 1) <> N'['
            THROW 51020, N'El detalle debe ser un arreglo JSON de líneas.', 1;

        CREATE TABLE #Rec (IdDetalle INT, Cantidad DECIMAL(18,2));
        INSERT INTO #Rec (IdDetalle, Cantidad)
        SELECT TRY_CAST(j.IdDetalle AS INT), TRY_CAST(j.Cantidad AS DECIMAL(18,2))
        FROM OPENJSON(@Detalle) WITH (IdDetalle NVARCHAR(50) '$.idDetalle', Cantidad NVARCHAR(50) '$.cantidad') AS j;

        IF NOT EXISTS (SELECT 1 FROM #Rec)
            THROW 51020, N'La recepción debe tener al menos una línea.', 1;
        IF EXISTS (SELECT 1 FROM #Rec WHERE IdDetalle IS NULL OR Cantidad IS NULL)
            THROW 51020, N'Cada línea requiere idDetalle y cantidad numéricos.', 1;
        IF EXISTS (SELECT 1 FROM #Rec WHERE Cantidad <= 0)
            THROW 51022, N'La cantidad recibida debe ser mayor que cero.', 1;
        IF EXISTS (SELECT IdDetalle FROM #Rec GROUP BY IdDetalle HAVING COUNT(*) > 1)
            THROW 51023, N'Una línea de la orden no puede repetirse en la misma recepción.', 1;

        DECLARE @estado VARCHAR(10), @idProv INT, @idBod INT, @fechaOrden DATE, @fechaEsp DATE,
                @dias INT, @tasa DECIMAL(5,4), @sub DECIMAL(18,2), @iva DECIMAL(18,2), @sec BIGINT;

        EXEC sys.sp_set_session_context @key = N'usuario', @value = @Usuario;

        BEGIN TRANSACTION;
            SELECT @estado = Estado, @idProv = IdProveedor, @idBod = IdBodega, @fechaOrden = FechaOrden,
                   @fechaEsp = FechaEsperada, @dias = DiasCredito, @tasa = TasaIva
            FROM compras.OrdenesCompra WITH (UPDLOCK, HOLDLOCK)
            WHERE IdOrdenCompra = @IdOrdenCompra;

            IF @estado IS NULL
                THROW 52002, N'La orden de compra no existe.', 1;
            IF @estado NOT IN ('Aprobada', 'Parcial')
                THROW 53009, N'Solo se puede recibir mercadería de órdenes Aprobadas o Parciales.', 1;
            IF @FechaRecepcion < @fechaOrden
                THROW 51024, N'La fecha de recepción no puede ser anterior a la fecha de la orden.', 1;
            IF EXISTS (SELECT 1 FROM compras.Recepciones
                       WHERE IdProveedor = @idProv
                         AND ISNULL(SerieFactura, '') = ISNULL(@SerieFactura, '')
                         AND NumeroFactura = @NumeroFactura)
                THROW 53011, N'Esa factura del proveedor ya fue registrada en otra recepción.', 1;
            IF EXISTS (SELECT 1 FROM #Rec AS r
                       LEFT JOIN compras.OrdenesCompraDetalle AS d
                              ON d.IdDetalle = r.IdDetalle AND d.IdOrdenCompra = @IdOrdenCompra
                       WHERE d.IdDetalle IS NULL)
                THROW 51031, N'Una o más líneas no pertenecen a esta orden de compra.', 1;
            IF EXISTS (SELECT 1 FROM #Rec AS r
                       INNER JOIN compras.OrdenesCompraDetalle AS d ON d.IdDetalle = r.IdDetalle
                       WHERE r.Cantidad > d.CantidadPedida - d.CantidadRecibida)
                THROW 51030, N'La cantidad recibida excede la cantidad pendiente de una o más líneas.', 1;

            SELECT @sub = SUM(CAST(r.Cantidad * d.CostoUnitario AS DECIMAL(18,2)))
            FROM #Rec AS r
            INNER JOIN compras.OrdenesCompraDetalle AS d ON d.IdDetalle = r.IdDetalle;
            SET @iva = ROUND(@sub * @tasa, 2);

            /* 2. Nota de compra */
            SET @sec = NEXT VALUE FOR compras.seq_Recepcion;
            INSERT INTO compras.Recepciones
                (Numero, IdOrdenCompra, IdProveedor, IdBodega, FechaRecepcion, FechaEsperada,
                 SerieFactura, NumeroFactura, Cumplimiento, DiasDiferencia,
                 Subtotal, Iva, Total, Observaciones, RecibidoPor)
            VALUES
                (compras.fn_FormatearNumero('RC-', @sec, 6), @IdOrdenCompra, @idProv, @idBod, @FechaRecepcion, @fechaEsp,
                 @SerieFactura, @NumeroFactura, compras.fn_Cumplimiento(@fechaEsp, @FechaRecepcion),
                 DATEDIFF(DAY, @fechaEsp, @FechaRecepcion),
                 @sub, @iva, @sub + @iva, NULLIF(LTRIM(RTRIM(@Observaciones)), N''), @Usuario);

            SET @IdRecepcion = SCOPE_IDENTITY();

            INSERT INTO compras.RecepcionesDetalle (IdRecepcion, IdDetalleOrden, IdProducto, Cantidad, CostoUnitario)
            SELECT @IdRecepcion, d.IdDetalle, d.IdProducto, r.Cantidad, d.CostoUnitario
            FROM #Rec AS r
            INNER JOIN compras.OrdenesCompraDetalle AS d ON d.IdDetalle = r.IdDetalle;

            /* 3. Cantidades recibidas */
            UPDATE d
               SET CantidadRecibida = d.CantidadRecibida + r.Cantidad
            FROM compras.OrdenesCompraDetalle AS d
            INNER JOIN #Rec AS r ON r.IdDetalle = d.IdDetalle;

            /* 4. INVENTARIO (tablas inv.*; punto de integración con el módulo de Inventarios) */
            UPDATE p
               SET CostoPromedio = ROUND((ISNULL(e.Existencia, 0) * p.CostoPromedio + r.Cantidad * d.CostoUnitario)
                                         / (ISNULL(e.Existencia, 0) + r.Cantidad), 4)
            FROM inv.Productos AS p
            INNER JOIN compras.OrdenesCompraDetalle AS d ON d.IdProducto = p.IdProducto
            INNER JOIN #Rec AS r ON r.IdDetalle = d.IdDetalle
            OUTER APPLY (SELECT SUM(x.Cantidad) AS Existencia
                         FROM inv.Existencias AS x
                         WHERE x.IdProducto = p.IdProducto) AS e;

            MERGE inv.Existencias AS t
            USING (SELECT d.IdProducto, r.Cantidad
                   FROM #Rec AS r
                   INNER JOIN compras.OrdenesCompraDetalle AS d ON d.IdDetalle = r.IdDetalle) AS s
               ON t.IdProducto = s.IdProducto AND t.IdBodega = @idBod
            WHEN MATCHED THEN
                UPDATE SET Cantidad = t.Cantidad + s.Cantidad, FechaActualizacion = SYSDATETIME()
            WHEN NOT MATCHED THEN
                INSERT (IdProducto, IdBodega, Cantidad) VALUES (s.IdProducto, @idBod, s.Cantidad);

            INSERT INTO inv.MovimientosInventario
                (IdProducto, IdBodega, Tipo, Cantidad, CostoUnitario, DocumentoOrigen, IdDocumento, Usuario)
            SELECT d.IdProducto, @idBod, 'ENTRADA', r.Cantidad, d.CostoUnitario, 'RECEPCION_COMPRA', @IdRecepcion, @Usuario
            FROM #Rec AS r
            INNER JOIN compras.OrdenesCompraDetalle AS d ON d.IdDetalle = r.IdDetalle;

            /* 5. Estado de la orden */
            UPDATE compras.OrdenesCompra
               SET Estado = CASE WHEN EXISTS (SELECT 1 FROM compras.OrdenesCompraDetalle
                                              WHERE IdOrdenCompra = @IdOrdenCompra
                                                AND CantidadRecibida < CantidadPedida)
                                 THEN 'Parcial' ELSE 'Recibida' END,
                   FechaModificacion = SYSDATETIME(),
                   ModificadoPor     = @Usuario
             WHERE IdOrdenCompra = @IdOrdenCompra;

            /* 6. Cuenta por pagar */
            SET @sec = NEXT VALUE FOR compras.seq_CuentaPagar;
            INSERT INTO compras.CuentasPorPagar
                (Numero, IdRecepcion, IdProveedor, FechaEmision, FechaVencimiento, Monto, Saldo, Estado)
            VALUES
                (compras.fn_FormatearNumero('CP-', @sec, 6), @IdRecepcion, @idProv, @FechaRecepcion,
                 DATEADD(DAY, @dias, @FechaRecepcion), @sub + @iva, @sub + @iva, 'Pendiente');
        COMMIT TRANSACTION;

        SELECT * FROM compras.vw_Recepciones WHERE IdRecepcion = @IdRecepcion;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        EXEC aud.sp_RegistrarError @Procedimiento = N'compras.sp_Recepcion_Registrar', @Parametros = @Detalle;
        IF ERROR_NUMBER() IN (2601, 2627) THROW 53011, N'Esa factura del proveedor ya fue registrada en otra recepción.', 1;
        THROW;
    END CATCH
END
GO

/* ======================= LISTAR / OBTENER RECEPCIONES ======================= */
CREATE OR ALTER PROCEDURE compras.sp_Recepcion_Listar
    @IdOrdenCompra  INT          = NULL,
    @IdProveedor    INT          = NULL,
    @Cumplimiento   VARCHAR(10)  = NULL,
    @FechaDesde     DATE         = NULL,
    @FechaHasta     DATE         = NULL,
    @Pagina         INT          = 1,
    @TamanoPagina   INT          = 10
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @Pagina < 1 OR @TamanoPagina NOT BETWEEN 1 AND 100
            THROW 51000, N'Paginación inválida: página >= 1 y tamaño entre 1 y 100.', 1;
        IF @Cumplimiento IS NOT NULL AND @Cumplimiento NOT IN ('ATiempo', 'Retraso', 'Anticipada')
            THROW 51000, N'Filtro de cumplimiento inválido.', 1;

        SELECT v.*, COUNT(*) OVER () AS TotalRegistros
        FROM compras.vw_Recepciones AS v
        WHERE (@IdOrdenCompra IS NULL OR v.IdOrdenCompra = @IdOrdenCompra)
          AND (@IdProveedor   IS NULL OR v.IdProveedor   = @IdProveedor)
          AND (@Cumplimiento  IS NULL OR v.Cumplimiento  = @Cumplimiento)
          AND (@FechaDesde    IS NULL OR v.FechaRecepcion >= @FechaDesde)
          AND (@FechaHasta    IS NULL OR v.FechaRecepcion <= @FechaHasta)
        ORDER BY v.FechaRecepcion DESC, v.IdRecepcion DESC
        OFFSET (@Pagina - 1) * @TamanoPagina ROWS
        FETCH NEXT @TamanoPagina ROWS ONLY
        OPTION (RECOMPILE);
    END TRY
    BEGIN CATCH
        EXEC aud.sp_RegistrarError @Procedimiento = N'compras.sp_Recepcion_Listar';
        THROW;
    END CATCH
END
GO

CREATE OR ALTER PROCEDURE compras.sp_Recepcion_Obtener
    @IdRecepcion INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM compras.Recepciones WHERE IdRecepcion = @IdRecepcion)
            THROW 52003, N'La recepción no existe.', 1;

        SELECT * FROM compras.vw_Recepciones WHERE IdRecepcion = @IdRecepcion;

        SELECT rd.IdRecepcionDetalle, rd.IdDetalleOrden, rd.IdProducto, p.Codigo AS CodigoProducto,
               p.Nombre AS Producto, p.UnidadMedida, rd.Cantidad, rd.CostoUnitario, rd.Subtotal
        FROM compras.RecepcionesDetalle AS rd
        INNER JOIN inv.Productos AS p ON p.IdProducto = rd.IdProducto
        WHERE rd.IdRecepcion = @IdRecepcion
        ORDER BY rd.IdRecepcionDetalle;
    END TRY
    BEGIN CATCH
        EXEC aud.sp_RegistrarError @Procedimiento = N'compras.sp_Recepcion_Obtener';
        THROW;
    END CATCH
END
GO

PRINT N'[OK] 09 - Procedimientos de Compras y Recepciones.';
GO
