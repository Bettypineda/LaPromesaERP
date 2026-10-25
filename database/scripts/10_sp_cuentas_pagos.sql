/* =====================================================================
   LA PROMESA ERP  |  10 - Procedimientos: CUENTAS POR PAGAR y PAGOS
   ---------------------------------------------------------------------
   Integración con la API externa de pagos bancarios (servicio
   independiente). Flujo de una transferencia:
     1) sp_Pago_Iniciar          -> pago 'Pendiente' + OperacionId (GUID)
     2) El backend llama a la API bancaria con ese OperacionId.
     3a) Respuesta OK/rechazo    -> sp_Pago_Confirmar (Aprobado/Rechazado)
     3b) Timeout / sin respuesta -> sp_Pago_RegistrarIntento (reintento
         acotado; al llegar al máximo queda Rechazado)
   Repetir el paso 1 con el mismo OperacionId NO duplica el pago
   (idempotencia). El saldo se rebaja solo cuando el pago es Aprobado.
   ===================================================================== */
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
USE LaPromesaERP;
GO

/* ========================= CUENTAS POR PAGAR ========================= */
CREATE OR ALTER PROCEDURE compras.sp_CuentaPagar_Listar
    @IdProveedor      INT          = NULL,
    @Estado           VARCHAR(10)  = NULL,   -- Pendiente | Parcial | Pagada
    @SoloVencidas     BIT          = 0,
    @SoloConSaldo     BIT          = 1,
    @VenceDesde       DATE         = NULL,
    @VenceHasta       DATE         = NULL,
    @Pagina           INT          = 1,
    @TamanoPagina     INT          = 10
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @Pagina < 1 OR @TamanoPagina NOT BETWEEN 1 AND 100
            THROW 51000, N'Paginación inválida: página >= 1 y tamaño entre 1 y 100.', 1;
        IF @Estado IS NOT NULL AND @Estado NOT IN ('Pendiente', 'Parcial', 'Pagada')
            THROW 51000, N'Filtro de estado inválido.', 1;
        IF @VenceDesde IS NOT NULL AND @VenceHasta IS NOT NULL AND @VenceDesde > @VenceHasta
            THROW 51024, N'La fecha inicial no puede ser mayor que la fecha final.', 1;

        SELECT v.*, COUNT(*) OVER () AS TotalRegistros
        FROM compras.vw_CuentasPorPagar AS v
        WHERE (@IdProveedor IS NULL OR v.IdProveedor = @IdProveedor)
          AND (@Estado      IS NULL OR v.Estado      = @Estado)
          AND (@SoloVencidas = 0 OR (v.DiasVencida > 0 AND v.Estado <> 'Pagada'))
          AND (@SoloConSaldo = 0 OR v.Estado <> 'Pagada')
          AND (@VenceDesde  IS NULL OR v.FechaVencimiento >= @VenceDesde)
          AND (@VenceHasta  IS NULL OR v.FechaVencimiento <= @VenceHasta)
        ORDER BY v.FechaVencimiento, v.IdCuentaPagar
        OFFSET (@Pagina - 1) * @TamanoPagina ROWS
        FETCH NEXT @TamanoPagina ROWS ONLY
        OPTION (RECOMPILE);
    END TRY
    BEGIN CATCH
        EXEC aud.sp_RegistrarError @Procedimiento = N'compras.sp_CuentaPagar_Listar';
        THROW;
    END CATCH
END
GO

/* Resultado 1: cuenta | 2: pagos */
CREATE OR ALTER PROCEDURE compras.sp_CuentaPagar_Obtener
    @IdCuentaPagar INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM compras.CuentasPorPagar WHERE IdCuentaPagar = @IdCuentaPagar)
            THROW 52004, N'La cuenta por pagar no existe.', 1;

        SELECT * FROM compras.vw_CuentasPorPagar WHERE IdCuentaPagar = @IdCuentaPagar;

        SELECT * FROM compras.vw_PagosProveedor WHERE IdCuentaPagar = @IdCuentaPagar ORDER BY FechaSolicitud, IdPago;
    END TRY
    BEGIN CATCH
        EXEC aud.sp_RegistrarError @Procedimiento = N'compras.sp_CuentaPagar_Obtener';
        THROW;
    END CATCH
END
GO

/* =========================== INICIAR PAGO =========================== */
CREATE OR ALTER PROCEDURE compras.sp_Pago_Iniciar
    @IdCuentaPagar  INT,
    @OperacionId    UNIQUEIDENTIFIER,
    @Monto          DECIMAL(18,2),
    @Metodo         VARCHAR(15),             -- Transferencia | Cheque | Efectivo
    @Banco          NVARCHAR(60) = NULL,     -- transferencia: por defecto el del proveedor
    @CuentaDestino  VARCHAR(30)  = NULL,
    @Referencia     VARCHAR(50)  = NULL,     -- cheque: número de cheque (obligatorio)
    @Usuario        NVARCHAR(100),
    @IdPago         INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF NULLIF(LTRIM(RTRIM(@Usuario)), N'') IS NULL
            THROW 51001, N'El usuario que realiza la operación es obligatorio.', 1;
        IF @OperacionId IS NULL
            THROW 51041, N'El identificador de operación (OperacionId) es obligatorio para evitar pagos duplicados.', 1;

        /* Idempotencia: la misma operación devuelve el mismo pago */
        DECLARE @cxpExistente INT, @montoExistente DECIMAL(18,2);
        SET @IdPago = NULL;
        SELECT @IdPago = IdPago, @cxpExistente = IdCuentaPagar, @montoExistente = Monto
        FROM compras.PagosProveedor WHERE OperacionId = @OperacionId;

        IF @IdPago IS NOT NULL
        BEGIN
            IF @cxpExistente <> @IdCuentaPagar OR @montoExistente <> @Monto
                THROW 53014, N'El identificador de operación ya fue usado con otros datos.', 1;
            SELECT * FROM compras.vw_PagosProveedor WHERE IdPago = @IdPago;
            RETURN;
        END

        IF @Monto IS NULL OR @Monto <= 0
            THROW 51040, N'El monto del pago debe ser mayor que cero.', 1;
        IF @Metodo IS NULL OR @Metodo NOT IN ('Transferencia', 'Cheque', 'Efectivo')
            THROW 51041, N'El método de pago debe ser Transferencia, Cheque o Efectivo.', 1;

        SET @Referencia = NULLIF(UPPER(LTRIM(RTRIM(@Referencia))), '');
        IF @Metodo = 'Cheque' AND @Referencia IS NULL
            THROW 51041, N'Para pagos con cheque indique el número de cheque.', 1;

        DECLARE @saldo DECIMAL(18,2), @estado VARCHAR(10), @idProv INT, @enProceso DECIMAL(18,2),
                @sec BIGINT, @msg NVARCHAR(300);

        EXEC sys.sp_set_session_context @key = N'usuario', @value = @Usuario;

        BEGIN TRANSACTION;
            SELECT @saldo = Saldo, @estado = Estado, @idProv = IdProveedor
            FROM compras.CuentasPorPagar WITH (UPDLOCK, HOLDLOCK)
            WHERE IdCuentaPagar = @IdCuentaPagar;

            IF @estado IS NULL      THROW 52004, N'La cuenta por pagar no existe.', 1;
            IF @estado = 'Pagada'   THROW 53018, N'La cuenta por pagar ya está pagada.', 1;

            IF @Metodo = 'Transferencia'
            BEGIN
                SELECT @Banco         = COALESCE(NULLIF(LTRIM(RTRIM(@Banco)), N''), Banco),
                       @CuentaDestino = COALESCE(NULLIF(LTRIM(RTRIM(@CuentaDestino)), ''), NumeroCuenta)
                FROM compras.Proveedores WHERE IdProveedor = @idProv;

                IF @Banco IS NULL OR @CuentaDestino IS NULL
                    THROW 51041, N'El proveedor no tiene datos bancarios; indique banco y cuenta destino.', 1;
            END

            SELECT @enProceso = ISNULL(SUM(Monto), 0)
            FROM compras.PagosProveedor
            WHERE IdCuentaPagar = @IdCuentaPagar AND Estado = 'Pendiente';

            IF @Monto > @saldo - @enProceso
            BEGIN
                SET @msg = CONCAT(N'El monto excede el saldo disponible. Saldo: Q', FORMAT(@saldo, 'N2'),
                                  N'; en proceso: Q', FORMAT(@enProceso, 'N2'), N'.');
                THROW 53013, @msg, 1;
            END

            SET @sec = NEXT VALUE FOR compras.seq_Pago;

            INSERT INTO compras.PagosProveedor
                (Numero, IdCuentaPagar, IdProveedor, OperacionId, Monto, Metodo, Banco, CuentaDestino,
                 ReferenciaBanco, Estado, FechaConfirmacion, RegistradoPor, ConfirmadoPor)
            VALUES
                (compras.fn_FormatearNumero('PG-', @sec, 6), @IdCuentaPagar, @idProv, @OperacionId, @Monto, @Metodo,
                 CASE WHEN @Metodo = 'Efectivo' THEN NULL ELSE @Banco END,
                 CASE WHEN @Metodo = 'Transferencia' THEN @CuentaDestino END,
                 CASE WHEN @Metodo = 'Cheque' THEN @Referencia END,
                 CASE WHEN @Metodo = 'Transferencia' THEN 'Pendiente' ELSE 'Aprobado' END,
                 CASE WHEN @Metodo = 'Transferencia' THEN NULL ELSE SYSDATETIME() END,
                 @Usuario,
                 CASE WHEN @Metodo = 'Transferencia' THEN NULL ELSE @Usuario END);

            SET @IdPago = SCOPE_IDENTITY();
        COMMIT TRANSACTION;

        SELECT * FROM compras.vw_PagosProveedor WHERE IdPago = @IdPago;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        EXEC aud.sp_RegistrarError @Procedimiento = N'compras.sp_Pago_Iniciar';
        IF ERROR_NUMBER() IN (2601, 2627) THROW 53014, N'Esta operación de pago ya fue registrada.', 1;
        THROW;
    END CATCH
END
GO

/* ===================== CONFIRMAR (respuesta del banco) ===================== */
CREATE OR ALTER PROCEDURE compras.sp_Pago_Confirmar
    @IdPago           INT,
    @Aprobado         BIT,
    @ReferenciaBanco  VARCHAR(50)   = NULL,   -- obligatoria si fue aprobado
    @MensajeBanco     NVARCHAR(250) = NULL,
    @Usuario          NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF NULLIF(LTRIM(RTRIM(@Usuario)), N'') IS NULL
            THROW 51001, N'El usuario que realiza la operación es obligatorio.', 1;
        IF @Aprobado IS NULL
            THROW 51041, N'Indique si el banco aprobó (1) o rechazó (0) el pago.', 1;

        SET @ReferenciaBanco = NULLIF(UPPER(LTRIM(RTRIM(@ReferenciaBanco))), '');
        IF @Aprobado = 1 AND @ReferenciaBanco IS NULL
            THROW 51041, N'Un pago aprobado requiere la referencia de autorización del banco.', 1;

        DECLARE @estado VARCHAR(10), @refActual VARCHAR(50);

        EXEC sys.sp_set_session_context @key = N'usuario', @value = @Usuario;

        BEGIN TRANSACTION;
            SELECT @estado = Estado, @refActual = ReferenciaBanco
            FROM compras.PagosProveedor WITH (UPDLOCK, HOLDLOCK)
            WHERE IdPago = @IdPago;

            IF @estado IS NULL THROW 52005, N'El pago no existe.', 1;

            IF @estado <> 'Pendiente'
            BEGIN
                -- Respuesta repetida del banco: idempotente si coincide
                IF (@estado = 'Aprobado' AND @Aprobado = 1 AND @refActual = @ReferenciaBanco)
                   OR (@estado = 'Rechazado' AND @Aprobado = 0)
                BEGIN
                    COMMIT TRANSACTION;
                    SELECT * FROM compras.vw_PagosProveedor WHERE IdPago = @IdPago;
                    RETURN;
                END;
                THROW 53015, N'El pago ya fue confirmado con otro resultado y no puede cambiarse.', 1;
            END

            UPDATE compras.PagosProveedor
               SET Estado            = CASE WHEN @Aprobado = 1 THEN 'Aprobado' ELSE 'Rechazado' END,
                   ReferenciaBanco   = @ReferenciaBanco,
                   MensajeBanco      = NULLIF(LTRIM(RTRIM(@MensajeBanco)), N''),
                   Intentos          = Intentos + 1,
                   FechaConfirmacion = SYSDATETIME(),
                   ConfirmadoPor     = @Usuario
             WHERE IdPago = @IdPago;
        COMMIT TRANSACTION;

        SELECT * FROM compras.vw_PagosProveedor WHERE IdPago = @IdPago;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        EXEC aud.sp_RegistrarError @Procedimiento = N'compras.sp_Pago_Confirmar';
        THROW;
    END CATCH
END
GO

/* ============ REGISTRAR INTENTO FALLIDO (timeout / banco caído) ============ */
CREATE OR ALTER PROCEDURE compras.sp_Pago_RegistrarIntento
    @IdPago        INT,
    @MensajeBanco  NVARCHAR(250),
    @Usuario       NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF NULLIF(LTRIM(RTRIM(@Usuario)), N'') IS NULL
            THROW 51001, N'El usuario que realiza la operación es obligatorio.', 1;

        DECLARE @estado VARCHAR(10), @intentos INT;
        DECLARE @max INT = ISNULL(TRY_CAST(cfg.fn_Parametro('PAGO_MAX_INTENTOS') AS INT), 3);

        EXEC sys.sp_set_session_context @key = N'usuario', @value = @Usuario;

        BEGIN TRANSACTION;
            SELECT @estado = Estado, @intentos = Intentos
            FROM compras.PagosProveedor WITH (UPDLOCK, HOLDLOCK)
            WHERE IdPago = @IdPago;

            IF @estado IS NULL          THROW 52005, N'El pago no existe.', 1;
            IF @estado <> 'Pendiente'   THROW 53015, N'Solo se registran intentos de pagos pendientes.', 1;

            UPDATE compras.PagosProveedor
               SET Intentos          = Intentos + 1,
                   MensajeBanco      = LEFT(CONCAT(N'Intento ', @intentos + 1, N': ', @MensajeBanco), 250),
                   Estado            = CASE WHEN @intentos + 1 >= @max THEN 'Rechazado' ELSE 'Pendiente' END,
                   FechaConfirmacion = CASE WHEN @intentos + 1 >= @max THEN SYSDATETIME() END,
                   ConfirmadoPor     = CASE WHEN @intentos + 1 >= @max THEN @Usuario END
             WHERE IdPago = @IdPago;
        COMMIT TRANSACTION;

        SELECT * FROM compras.vw_PagosProveedor WHERE IdPago = @IdPago;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        EXEC aud.sp_RegistrarError @Procedimiento = N'compras.sp_Pago_RegistrarIntento';
        THROW;
    END CATCH
END
GO

/* Pagos pendientes de respuesta del banco (para reintentos o revisión) */
CREATE OR ALTER PROCEDURE compras.sp_Pago_ListarPendientes
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM compras.vw_PagosProveedor
    WHERE Estado = 'Pendiente'
    ORDER BY FechaSolicitud;
END
GO

PRINT N'[OK] 10 - Procedimientos de Cuentas por pagar y Pagos.';
GO
