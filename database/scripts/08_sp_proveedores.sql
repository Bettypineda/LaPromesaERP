/* =====================================================================
   LA PROMESA ERP  |  08 - Procedimientos: CATEGORÍAS y PROVEEDORES
   ---------------------------------------------------------------------
   CRUD completo de Proveedores:
     Listar (búsqueda, filtros, orden, paginación) | Obtener (con
     historial) | Crear | Actualizar (concurrencia) | Inactivar |
     Reactivar
   Patrón de todos los procedimientos:
     SET XACT_ABORT ON + BEGIN TRY / BEGIN TRANSACTION / COMMIT
     BEGIN CATCH -> ROLLBACK -> aud.sp_RegistrarError -> THROW
   Códigos de error: ver database/README.md (51xxx validación = 400,
   52xxx no existe = 404, 53xxx regla/estado = 409, 54xxx concurrencia = 409).
   ===================================================================== */
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
USE LaPromesaERP;
GO

/* =============================== CATEGORÍAS =============================== */
CREATE OR ALTER PROCEDURE compras.sp_Categoria_Listar
    @SoloActivas BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SELECT IdCategoria, Nombre, Descripcion, Activo, FechaCreacion, CreadoPor
    FROM compras.CategoriasProveedor
    WHERE @SoloActivas = 0 OR Activo = 1
    ORDER BY Nombre;
END
GO

CREATE OR ALTER PROCEDURE compras.sp_Categoria_Crear
    @Nombre       NVARCHAR(50),
    @Descripcion  NVARCHAR(200) = NULL,
    @Usuario      NVARCHAR(100),
    @IdCategoria  INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), N'');
        IF NULLIF(LTRIM(RTRIM(@Usuario)), N'') IS NULL THROW 51001, N'El usuario que realiza la operación es obligatorio.', 1;
        IF @Nombre IS NULL OR LEN(@Nombre) < 3           THROW 51018, N'El nombre de la categoría es obligatorio (mínimo 3 caracteres).', 1;
        IF EXISTS (SELECT 1 FROM compras.CategoriasProveedor WHERE Nombre = @Nombre)
            THROW 53021, N'Ya existe una categoría con ese nombre.', 1;

        EXEC sys.sp_set_session_context @key = N'usuario', @value = @Usuario;

        BEGIN TRANSACTION;
            INSERT INTO compras.CategoriasProveedor (Nombre, Descripcion, CreadoPor)
            VALUES (@Nombre, NULLIF(LTRIM(RTRIM(@Descripcion)), N''), @Usuario);
            SET @IdCategoria = SCOPE_IDENTITY();
        COMMIT TRANSACTION;

        SELECT IdCategoria, Nombre, Descripcion, Activo FROM compras.CategoriasProveedor WHERE IdCategoria = @IdCategoria;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        EXEC aud.sp_RegistrarError @Procedimiento = N'compras.sp_Categoria_Crear';
        IF ERROR_NUMBER() IN (2601, 2627) THROW 53021, N'Ya existe una categoría con ese nombre.', 1;
        THROW;
    END CATCH
END
GO

/* ===================== VALIDACIÓN COMÚN DE PROVEEDOR =====================
   Usado por Crear y Actualizar. Devuelve NIT y teléfono normalizados.     */
CREATE OR ALTER PROCEDURE compras.sp_Proveedor_ValidarDatos
    @Nombre               NVARCHAR(150),
    @Nit                  VARCHAR(20),
    @IdCategoria          INT,
    @Telefono             VARCHAR(20),
    @Email                NVARCHAR(150),
    @TipoPago             VARCHAR(10),
    @DiasCredito          INT,
    @LimiteCredito        DECIMAL(18,2),
    @Banco                NVARCHAR(60),
    @NumeroCuenta         VARCHAR(30),
    @IdProveedorExcluir   INT = NULL,
    @NitNormalizado       VARCHAR(15) OUTPUT,
    @TelefonoNormalizado  VARCHAR(9)  OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @msg NVARCHAR(400);
    DECLARE @maxDias INT = ISNULL(TRY_CAST(cfg.fn_Parametro('DIAS_CREDITO_MAX') AS INT), 180);

    IF @Nombre IS NULL OR LEN(LTRIM(RTRIM(@Nombre))) < 3
        THROW 51010, N'El nombre del proveedor es obligatorio (mínimo 3 caracteres).', 1;

    IF @Nit IS NULL OR compras.fn_NitValido(@Nit) = 0
        THROW 51011, N'El NIT no es válido. Verifique el número y el dígito verificador (ej. 1234567-9).', 1;

    SET @NitNormalizado = compras.fn_NitNormalizado(@Nit);

    IF EXISTS (SELECT 1 FROM compras.Proveedores
               WHERE Nit = @NitNormalizado
                 AND (@IdProveedorExcluir IS NULL OR IdProveedor <> @IdProveedorExcluir))
        THROW 53002, N'Ya existe un proveedor registrado con ese NIT.', 1;

    IF NOT EXISTS (SELECT 1 FROM compras.CategoriasProveedor WHERE IdCategoria = @IdCategoria AND Activo = 1)
        THROW 51018, N'La categoría indicada no existe o está inactiva.', 1;

    SET @TelefonoNormalizado = NULL;
    IF NULLIF(LTRIM(RTRIM(@Telefono)), '') IS NOT NULL
    BEGIN
        SET @TelefonoNormalizado = compras.fn_TelefonoNormalizado(@Telefono);
        IF @TelefonoNormalizado IS NULL
            THROW 51012, N'El teléfono debe tener 8 dígitos y comenzar con 2 a 7 (ej. 2360-1111).', 1;
    END

    IF NULLIF(LTRIM(RTRIM(@Email)), N'') IS NOT NULL
       AND (LTRIM(RTRIM(@Email)) NOT LIKE N'%_@_%._%' OR LTRIM(RTRIM(@Email)) LIKE N'% %')
        THROW 51013, N'El correo electrónico no tiene un formato válido.', 1;

    IF @TipoPago IS NULL OR @TipoPago NOT IN ('Contado', 'Credito')
        THROW 51014, N'El tipo de pago debe ser Contado o Credito.', 1;

    IF @TipoPago = 'Contado' AND ISNULL(@DiasCredito, 0) <> 0
        THROW 51015, N'Un proveedor de contado debe tener 0 días de crédito.', 1;

    IF @TipoPago = 'Credito' AND (@DiasCredito IS NULL OR @DiasCredito < 1 OR @DiasCredito > @maxDias)
    BEGIN
        SET @msg = CONCAT(N'Un proveedor al crédito debe tener entre 1 y ', @maxDias, N' días de crédito.');
        THROW 51015, @msg, 1;
    END

    IF ISNULL(@LimiteCredito, 0) < 0 OR (@TipoPago = 'Contado' AND ISNULL(@LimiteCredito, 0) <> 0)
        THROW 51016, N'El límite de crédito no puede ser negativo y debe ser 0 para proveedores de contado.', 1;

    IF (NULLIF(LTRIM(RTRIM(@Banco)), N'') IS NULL AND NULLIF(LTRIM(RTRIM(@NumeroCuenta)), '') IS NOT NULL)
       OR (NULLIF(LTRIM(RTRIM(@Banco)), N'') IS NOT NULL AND NULLIF(LTRIM(RTRIM(@NumeroCuenta)), '') IS NULL)
        THROW 51019, N'Si registra datos bancarios, indique el banco y el número de cuenta.', 1;
END
GO

/* =============================== LISTAR =============================== */
CREATE OR ALTER PROCEDURE compras.sp_Proveedor_Listar
    @Buscar        NVARCHAR(100) = NULL,   -- nombre, NIT, contacto o código
    @Estado        VARCHAR(10)   = NULL,   -- Activo | Inactivo | NULL (todos)
    @TipoPago      VARCHAR(10)   = NULL,   -- Contado | Credito
    @IdCategoria   INT           = NULL,
    @OrdenarPor    VARCHAR(20)   = 'Nombre',
    @Direccion     VARCHAR(4)    = 'ASC',
    @Pagina        INT           = 1,
    @TamanoPagina  INT           = 10
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @Pagina < 1 OR @TamanoPagina NOT BETWEEN 1 AND 100
            THROW 51000, N'Paginación inválida: página >= 1 y tamaño entre 1 y 100.', 1;
        IF @OrdenarPor NOT IN ('Codigo', 'Nombre', 'Nit', 'Categoria', 'TipoPago', 'DiasCredito', 'Estado', 'FechaCreacion', 'SaldoPendiente')
            THROW 51000, N'Campo de ordenamiento no permitido.', 1;
        IF @Direccion NOT IN ('ASC', 'DESC')
            THROW 51000, N'La dirección de ordenamiento debe ser ASC o DESC.', 1;
        IF @Estado IS NOT NULL AND @Estado NOT IN ('Activo', 'Inactivo')
            THROW 51000, N'Filtro de estado inválido.', 1;
        IF @TipoPago IS NOT NULL AND @TipoPago NOT IN ('Contado', 'Credito')
            THROW 51000, N'Filtro de tipo de pago inválido.', 1;

        -- Escapar comodines de LIKE para buscar el texto literal
        DECLARE @b NVARCHAR(110) = NULLIF(LTRIM(RTRIM(@Buscar)), N'');
        SET @b = REPLACE(REPLACE(REPLACE(@b, N'[', N'[[]'), N'%', N'[%]'), N'_', N'[_]');

        SELECT
            v.IdProveedor, v.Codigo, v.Nombre, v.Nit, v.IdCategoria, v.Categoria,
            v.Contacto, v.Telefono, v.Email, v.Departamento,
            v.TipoPago, v.DiasCredito, v.LimiteCredito, v.Estado,
            v.OrdenesAbiertas, v.SaldoPendiente, v.CreditoDisponible, v.UltimaCompra,
            v.FechaCreacion, v.RowVersion,
            COUNT(*) OVER () AS TotalRegistros
        FROM compras.vw_Proveedores AS v
        WHERE (@b IS NULL OR v.Nombre LIKE N'%' + @b + N'%'
                          OR v.Nit LIKE N'%' + @b + N'%'
                          OR v.Contacto LIKE N'%' + @b + N'%'
                          OR v.Codigo LIKE N'%' + @b + N'%')
          AND (@Estado      IS NULL OR v.Estado      = @Estado)
          AND (@TipoPago    IS NULL OR v.TipoPago    = @TipoPago)
          AND (@IdCategoria IS NULL OR v.IdCategoria = @IdCategoria)
        ORDER BY
            CASE WHEN @Direccion = 'ASC'  AND @OrdenarPor = 'Codigo'         THEN v.Codigo        END ASC,
            CASE WHEN @Direccion = 'DESC' AND @OrdenarPor = 'Codigo'         THEN v.Codigo        END DESC,
            CASE WHEN @Direccion = 'ASC'  AND @OrdenarPor = 'Nombre'         THEN v.Nombre        END ASC,
            CASE WHEN @Direccion = 'DESC' AND @OrdenarPor = 'Nombre'         THEN v.Nombre        END DESC,
            CASE WHEN @Direccion = 'ASC'  AND @OrdenarPor = 'Nit'            THEN v.Nit           END ASC,
            CASE WHEN @Direccion = 'DESC' AND @OrdenarPor = 'Nit'            THEN v.Nit           END DESC,
            CASE WHEN @Direccion = 'ASC'  AND @OrdenarPor = 'Categoria'      THEN v.Categoria     END ASC,
            CASE WHEN @Direccion = 'DESC' AND @OrdenarPor = 'Categoria'      THEN v.Categoria     END DESC,
            CASE WHEN @Direccion = 'ASC'  AND @OrdenarPor = 'TipoPago'       THEN v.TipoPago      END ASC,
            CASE WHEN @Direccion = 'DESC' AND @OrdenarPor = 'TipoPago'       THEN v.TipoPago      END DESC,
            CASE WHEN @Direccion = 'ASC'  AND @OrdenarPor = 'DiasCredito'    THEN v.DiasCredito   END ASC,
            CASE WHEN @Direccion = 'DESC' AND @OrdenarPor = 'DiasCredito'    THEN v.DiasCredito   END DESC,
            CASE WHEN @Direccion = 'ASC'  AND @OrdenarPor = 'Estado'         THEN v.Estado        END ASC,
            CASE WHEN @Direccion = 'DESC' AND @OrdenarPor = 'Estado'         THEN v.Estado        END DESC,
            CASE WHEN @Direccion = 'ASC'  AND @OrdenarPor = 'FechaCreacion'  THEN v.FechaCreacion END ASC,
            CASE WHEN @Direccion = 'DESC' AND @OrdenarPor = 'FechaCreacion'  THEN v.FechaCreacion END DESC,
            CASE WHEN @Direccion = 'ASC'  AND @OrdenarPor = 'SaldoPendiente' THEN v.SaldoPendiente END ASC,
            CASE WHEN @Direccion = 'DESC' AND @OrdenarPor = 'SaldoPendiente' THEN v.SaldoPendiente END DESC,
            v.IdProveedor
        OFFSET (@Pagina - 1) * @TamanoPagina ROWS
        FETCH NEXT @TamanoPagina ROWS ONLY
        OPTION (RECOMPILE);
    END TRY
    BEGIN CATCH
        EXEC aud.sp_RegistrarError @Procedimiento = N'compras.sp_Proveedor_Listar';
        THROW;
    END CATCH
END
GO

/* ===================== OBTENER (detalle + historial) =====================
   Resultado 1: proveedor | 2: últimas 20 órdenes | 3: cuentas por pagar
   abiertas | 4: cumplimiento histórico                                    */
CREATE OR ALTER PROCEDURE compras.sp_Proveedor_Obtener
    @IdProveedor INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM compras.Proveedores WHERE IdProveedor = @IdProveedor)
            THROW 52001, N'El proveedor no existe.', 1;

        SELECT * FROM compras.vw_Proveedores WHERE IdProveedor = @IdProveedor;

        SELECT TOP (20) IdOrdenCompra, Numero, FechaOrden, FechaEsperada, Bodega, Total, Estado,
                        PorcentajeRecibido, EstaAtrasada
        FROM compras.vw_OrdenesCompra
        WHERE IdProveedor = @IdProveedor
        ORDER BY FechaOrden DESC, IdOrdenCompra DESC;

        SELECT IdCuentaPagar, Numero, NumeroOrden, FacturaProveedor, FechaEmision, FechaVencimiento,
               Monto, Saldo, Estado, DiasVencida, RangoAntiguedad
        FROM compras.vw_CuentasPorPagar
        WHERE IdProveedor = @IdProveedor AND Estado <> 'Pagada'
        ORDER BY FechaVencimiento;

        SELECT TotalRecepciones, ATiempo, Retraso, Anticipada, PorcentajeCumplimiento
        FROM compras.vw_CumplimientoProveedores
        WHERE IdProveedor = @IdProveedor;
    END TRY
    BEGIN CATCH
        EXEC aud.sp_RegistrarError @Procedimiento = N'compras.sp_Proveedor_Obtener';
        THROW;
    END CATCH
END
GO

/* ================================ CREAR ================================ */
CREATE OR ALTER PROCEDURE compras.sp_Proveedor_Crear
    @Nombre         NVARCHAR(150),
    @Nit            VARCHAR(20),
    @IdCategoria    INT,
    @Contacto       NVARCHAR(100) = NULL,
    @Telefono       VARCHAR(20)   = NULL,
    @Email          NVARCHAR(150) = NULL,
    @Direccion      NVARCHAR(200) = NULL,
    @Departamento   NVARCHAR(50)  = NULL,
    @TipoPago       VARCHAR(10),
    @DiasCredito    INT           = 0,
    @LimiteCredito  DECIMAL(18,2) = 0,
    @Banco          NVARCHAR(60)  = NULL,
    @NumeroCuenta   VARCHAR(30)   = NULL,
    @Usuario        NVARCHAR(100),
    @IdProveedor    INT = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF NULLIF(LTRIM(RTRIM(@Usuario)), N'') IS NULL
            THROW 51001, N'El usuario que realiza la operación es obligatorio.', 1;

        DECLARE @nitFinal VARCHAR(15), @telFinal VARCHAR(9), @sec INT;

        EXEC compras.sp_Proveedor_ValidarDatos
             @Nombre = @Nombre, @Nit = @Nit, @IdCategoria = @IdCategoria, @Telefono = @Telefono,
             @Email = @Email, @TipoPago = @TipoPago, @DiasCredito = @DiasCredito,
             @LimiteCredito = @LimiteCredito, @Banco = @Banco, @NumeroCuenta = @NumeroCuenta,
             @IdProveedorExcluir = NULL,
             @NitNormalizado = @nitFinal OUTPUT, @TelefonoNormalizado = @telFinal OUTPUT;

        EXEC sys.sp_set_session_context @key = N'usuario', @value = @Usuario;

        BEGIN TRANSACTION;
            SET @sec = NEXT VALUE FOR compras.seq_Proveedor;

            INSERT INTO compras.Proveedores
                (Codigo, Nombre, Nit, IdCategoria, Contacto, Telefono, Email, Direccion, Departamento,
                 TipoPago, DiasCredito, LimiteCredito, Banco, NumeroCuenta, Estado, CreadoPor)
            VALUES
                (compras.fn_FormatearNumero('PR', @sec, 3),
                 LTRIM(RTRIM(@Nombre)), @nitFinal, @IdCategoria,
                 NULLIF(LTRIM(RTRIM(@Contacto)), N''), @telFinal,
                 LOWER(NULLIF(LTRIM(RTRIM(@Email)), N'')),
                 NULLIF(LTRIM(RTRIM(@Direccion)), N''), NULLIF(LTRIM(RTRIM(@Departamento)), N''),
                 @TipoPago, ISNULL(@DiasCredito, 0), ISNULL(@LimiteCredito, 0),
                 NULLIF(LTRIM(RTRIM(@Banco)), N''), NULLIF(LTRIM(RTRIM(@NumeroCuenta)), ''),
                 'Activo', @Usuario);

            SET @IdProveedor = SCOPE_IDENTITY();
        COMMIT TRANSACTION;

        SELECT * FROM compras.vw_Proveedores WHERE IdProveedor = @IdProveedor;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        EXEC aud.sp_RegistrarError @Procedimiento = N'compras.sp_Proveedor_Crear';
        IF ERROR_NUMBER() IN (2601, 2627) THROW 53002, N'Ya existe un proveedor registrado con ese NIT.', 1;
        THROW;
    END CATCH
END
GO

/* ============================== ACTUALIZAR ==============================
   Requiere el RowVersion leído al abrir el formulario: si otro usuario
   guardó antes, se rechaza (concurrencia optimista).                     */
CREATE OR ALTER PROCEDURE compras.sp_Proveedor_Actualizar
    @IdProveedor    INT,
    @Nombre         NVARCHAR(150),
    @Nit            VARCHAR(20),
    @IdCategoria    INT,
    @Contacto       NVARCHAR(100) = NULL,
    @Telefono       VARCHAR(20)   = NULL,
    @Email          NVARCHAR(150) = NULL,
    @Direccion      NVARCHAR(200) = NULL,
    @Departamento   NVARCHAR(50)  = NULL,
    @TipoPago       VARCHAR(10),
    @DiasCredito    INT           = 0,
    @LimiteCredito  DECIMAL(18,2) = 0,
    @Banco          NVARCHAR(60)  = NULL,
    @NumeroCuenta   VARCHAR(30)   = NULL,
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
        IF NOT EXISTS (SELECT 1 FROM compras.Proveedores WHERE IdProveedor = @IdProveedor)
            THROW 52001, N'El proveedor no existe.', 1;

        DECLARE @nitFinal VARCHAR(15), @telFinal VARCHAR(9), @estado VARCHAR(10), @rv BINARY(8);

        EXEC compras.sp_Proveedor_ValidarDatos
             @Nombre = @Nombre, @Nit = @Nit, @IdCategoria = @IdCategoria, @Telefono = @Telefono,
             @Email = @Email, @TipoPago = @TipoPago, @DiasCredito = @DiasCredito,
             @LimiteCredito = @LimiteCredito, @Banco = @Banco, @NumeroCuenta = @NumeroCuenta,
             @IdProveedorExcluir = @IdProveedor,
             @NitNormalizado = @nitFinal OUTPUT, @TelefonoNormalizado = @telFinal OUTPUT;

        EXEC sys.sp_set_session_context @key = N'usuario', @value = @Usuario;

        BEGIN TRANSACTION;
            SELECT @estado = Estado, @rv = RowVersion
            FROM compras.Proveedores WITH (UPDLOCK, HOLDLOCK)
            WHERE IdProveedor = @IdProveedor;

            IF @rv <> @RowVersion
                THROW 54001, N'El proveedor fue modificado por otro usuario. Recargue los datos e intente de nuevo.', 1;
            IF @estado = 'Inactivo'
                THROW 53003, N'Un proveedor inactivo no puede editarse; reactívelo primero.', 1;

            UPDATE compras.Proveedores
               SET Nombre            = LTRIM(RTRIM(@Nombre)),
                   Nit               = @nitFinal,
                   IdCategoria       = @IdCategoria,
                   Contacto          = NULLIF(LTRIM(RTRIM(@Contacto)), N''),
                   Telefono          = @telFinal,
                   Email             = LOWER(NULLIF(LTRIM(RTRIM(@Email)), N'')),
                   Direccion         = NULLIF(LTRIM(RTRIM(@Direccion)), N''),
                   Departamento      = NULLIF(LTRIM(RTRIM(@Departamento)), N''),
                   TipoPago          = @TipoPago,
                   DiasCredito       = ISNULL(@DiasCredito, 0),
                   LimiteCredito     = ISNULL(@LimiteCredito, 0),
                   Banco             = NULLIF(LTRIM(RTRIM(@Banco)), N''),
                   NumeroCuenta      = NULLIF(LTRIM(RTRIM(@NumeroCuenta)), ''),
                   FechaModificacion = SYSDATETIME(),
                   ModificadoPor     = @Usuario
             WHERE IdProveedor = @IdProveedor;
        COMMIT TRANSACTION;

        SELECT * FROM compras.vw_Proveedores WHERE IdProveedor = @IdProveedor;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        EXEC aud.sp_RegistrarError @Procedimiento = N'compras.sp_Proveedor_Actualizar';
        IF ERROR_NUMBER() IN (2601, 2627) THROW 53002, N'Ya existe un proveedor registrado con ese NIT.', 1;
        THROW;
    END CATCH
END
GO

/* ============================== INACTIVAR ============================== */
CREATE OR ALTER PROCEDURE compras.sp_Proveedor_Inactivar
    @IdProveedor  INT,
    @Motivo       NVARCHAR(250),
    @RowVersion   BINARY(8) = NULL,
    @Usuario      NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF NULLIF(LTRIM(RTRIM(@Usuario)), N'') IS NULL
            THROW 51001, N'El usuario que realiza la operación es obligatorio.', 1;
        SET @Motivo = NULLIF(LTRIM(RTRIM(@Motivo)), N'');
        IF @Motivo IS NULL OR LEN(@Motivo) < 10
            THROW 51017, N'El motivo es obligatorio (mínimo 10 caracteres).', 1;

        DECLARE @estado VARCHAR(10), @rv BINARY(8);

        EXEC sys.sp_set_session_context @key = N'usuario', @value = @Usuario;

        BEGIN TRANSACTION;
            SELECT @estado = Estado, @rv = RowVersion
            FROM compras.Proveedores WITH (UPDLOCK, HOLDLOCK)
            WHERE IdProveedor = @IdProveedor;

            IF @estado IS NULL       THROW 52001, N'El proveedor no existe.', 1;
            IF @RowVersion IS NOT NULL AND @rv <> @RowVersion
                THROW 54001, N'El proveedor fue modificado por otro usuario. Recargue los datos e intente de nuevo.', 1;
            IF @estado = 'Inactivo'  THROW 53004, N'El proveedor ya está inactivo.', 1;
            IF EXISTS (SELECT 1 FROM compras.OrdenesCompra
                       WHERE IdProveedor = @IdProveedor AND Estado IN ('Pendiente', 'Aprobada', 'Parcial'))
                THROW 53005, N'No se puede inactivar un proveedor con órdenes de compra abiertas (Pendiente, Aprobada o Parcial).', 1;

            UPDATE compras.Proveedores
               SET Estado             = 'Inactivo',
                   FechaInactivacion  = SYSDATETIME(),
                   InactivadoPor      = @Usuario,
                   MotivoInactivacion = @Motivo,
                   FechaModificacion  = SYSDATETIME(),
                   ModificadoPor      = @Usuario
             WHERE IdProveedor = @IdProveedor;
        COMMIT TRANSACTION;

        SELECT * FROM compras.vw_Proveedores WHERE IdProveedor = @IdProveedor;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        EXEC aud.sp_RegistrarError @Procedimiento = N'compras.sp_Proveedor_Inactivar';
        THROW;
    END CATCH
END
GO

/* ============================== REACTIVAR ==============================
   Los datos de la inactivación anterior quedan en aud.Bitacora.          */
CREATE OR ALTER PROCEDURE compras.sp_Proveedor_Reactivar
    @IdProveedor  INT,
    @RowVersion   BINARY(8) = NULL,
    @Usuario      NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        IF NULLIF(LTRIM(RTRIM(@Usuario)), N'') IS NULL
            THROW 51001, N'El usuario que realiza la operación es obligatorio.', 1;

        DECLARE @estado VARCHAR(10), @rv BINARY(8);

        EXEC sys.sp_set_session_context @key = N'usuario', @value = @Usuario;

        BEGIN TRANSACTION;
            SELECT @estado = Estado, @rv = RowVersion
            FROM compras.Proveedores WITH (UPDLOCK, HOLDLOCK)
            WHERE IdProveedor = @IdProveedor;

            IF @estado IS NULL      THROW 52001, N'El proveedor no existe.', 1;
            IF @RowVersion IS NOT NULL AND @rv <> @RowVersion
                THROW 54001, N'El proveedor fue modificado por otro usuario. Recargue los datos e intente de nuevo.', 1;
            IF @estado = 'Activo'   THROW 53004, N'El proveedor ya está activo.', 1;

            UPDATE compras.Proveedores
               SET Estado             = 'Activo',
                   FechaInactivacion  = NULL,
                   InactivadoPor      = NULL,
                   MotivoInactivacion = NULL,
                   FechaModificacion  = SYSDATETIME(),
                   ModificadoPor      = @Usuario
             WHERE IdProveedor = @IdProveedor;
        COMMIT TRANSACTION;

        SELECT * FROM compras.vw_Proveedores WHERE IdProveedor = @IdProveedor;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        EXEC aud.sp_RegistrarError @Procedimiento = N'compras.sp_Proveedor_Reactivar';
        THROW;
    END CATCH
END
GO

PRINT N'[OK] 08 - Procedimientos de Proveedores.';
GO
