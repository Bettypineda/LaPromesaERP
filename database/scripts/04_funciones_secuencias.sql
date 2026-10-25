/* =====================================================================
   LA PROMESA ERP  |  04 - Funciones y secuencias
   ---------------------------------------------------------------------
   Secuencias: numeración correlativa sin huecos lógicos por tipo de
   documento (PR001, OC-000001, RC-000001, CP-000001, PG-000001).
   Funciones : validación de NIT guatemalteco (módulo 11), teléfono,
   cumplimiento de entrega (RQ27), antigüedad de saldos y parámetros.
   ===================================================================== */
SET NOCOUNT ON;
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
USE LaPromesaERP;
GO

/* ------------------------------ SECUENCIAS ------------------------------ */
IF OBJECT_ID(N'compras.seq_Proveedor',   N'SO') IS NULL CREATE SEQUENCE compras.seq_Proveedor   AS INT    START WITH 1 INCREMENT BY 1 NO CYCLE;
IF OBJECT_ID(N'compras.seq_OrdenCompra', N'SO') IS NULL CREATE SEQUENCE compras.seq_OrdenCompra AS BIGINT START WITH 1 INCREMENT BY 1 NO CYCLE;
IF OBJECT_ID(N'compras.seq_Recepcion',   N'SO') IS NULL CREATE SEQUENCE compras.seq_Recepcion   AS BIGINT START WITH 1 INCREMENT BY 1 NO CYCLE;
IF OBJECT_ID(N'compras.seq_CuentaPagar', N'SO') IS NULL CREATE SEQUENCE compras.seq_CuentaPagar AS BIGINT START WITH 1 INCREMENT BY 1 NO CYCLE;
IF OBJECT_ID(N'compras.seq_Pago',        N'SO') IS NULL CREATE SEQUENCE compras.seq_Pago        AS BIGINT START WITH 1 INCREMENT BY 1 NO CYCLE;
GO

/* ------------------------------ PARÁMETROS ------------------------------ */
CREATE OR ALTER FUNCTION cfg.fn_Parametro (@Clave VARCHAR(50))
RETURNS NVARCHAR(200)
AS
BEGIN
    RETURN (SELECT Valor FROM cfg.Parametros WHERE Clave = @Clave);
END
GO

/* --------------------------- NIT GUATEMALTECO ---------------------------
   Algoritmo SAT (módulo 11):
     - Se separa el cuerpo numérico del dígito verificador.
     - Cada dígito del cuerpo se multiplica por su posición contando
       desde la derecha empezando en 2.
     - verificador = (11 - (suma MOD 11)) MOD 11 ; si es 10 -> 'K'.
   Acepta "1234567-9", "12345679", "1234567 9" (se normaliza).
   ------------------------------------------------------------------------ */
/* Se crea solo si no existe: un CHECK de compras.Proveedores la usa y
   SQL Server no permite ALTER sobre una función referenciada por un CHECK. */
IF OBJECT_ID(N'compras.fn_NitValido', N'FN') IS NULL
EXEC (N'
CREATE FUNCTION compras.fn_NitValido (@Nit VARCHAR(20))
RETURNS BIT
WITH SCHEMABINDING
AS
BEGIN
    DECLARE @n VARCHAR(20) = UPPER(REPLACE(REPLACE(LTRIM(RTRIM(@Nit)), ''-'', ''''), '' '', ''''));
    IF @n IS NULL OR LEN(@n) < 2 OR LEN(@n) > 13 RETURN 0;

    DECLARE @cuerpo VARCHAR(20) = LEFT(@n, LEN(@n) - 1);
    DECLARE @dv     CHAR(1)     = RIGHT(@n, 1);
    IF @cuerpo LIKE ''%[^0-9]%'' RETURN 0;
    IF @dv NOT LIKE ''[0-9K]''   RETURN 0;

    DECLARE @i INT = 1, @largo INT = LEN(@cuerpo), @suma INT = 0;
    WHILE @i <= @largo
    BEGIN
        SET @suma += CAST(SUBSTRING(@cuerpo, @i, 1) AS INT) * (@largo - @i + 2);
        SET @i += 1;
    END

    DECLARE @r INT = (11 - (@suma % 11)) % 11;
    RETURN CASE
               WHEN @r = 10 AND @dv = ''K'' THEN 1
               WHEN @r < 10 AND @dv = CAST(@r AS CHAR(1)) THEN 1
               ELSE 0
           END;
END
');
GO

/* Devuelve el NIT con formato estándar CUERPO-DV (ej. 1234567-9) */
CREATE OR ALTER FUNCTION compras.fn_NitNormalizado (@Nit VARCHAR(20))
RETURNS VARCHAR(15)
WITH SCHEMABINDING
AS
BEGIN
    DECLARE @n VARCHAR(20) = UPPER(REPLACE(REPLACE(LTRIM(RTRIM(@Nit)), '-', ''), ' ', ''));
    IF @n IS NULL OR LEN(@n) < 2 RETURN NULL;
    RETURN CONCAT(LEFT(@n, LEN(@n) - 1), '-', RIGHT(@n, 1));
END
GO

/* Teléfono Guatemala: 8 dígitos iniciando en 2-7. Devuelve "NNNN-NNNN" o NULL si es inválido. */
CREATE OR ALTER FUNCTION compras.fn_TelefonoNormalizado (@Telefono VARCHAR(20))
RETURNS VARCHAR(9)
WITH SCHEMABINDING
AS
BEGIN
    DECLARE @t VARCHAR(20) = REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(@Telefono)), '-', ''), ' ', ''), '(', ''), ')', '');
    IF LEFT(@t, 4) = '+502' SET @t = SUBSTRING(@t, 5, 20);
    IF @t IS NULL OR LEN(@t) <> 8 OR @t LIKE '%[^0-9]%' OR LEFT(@t, 1) NOT LIKE '[2-7]' RETURN NULL;
    RETURN CONCAT(LEFT(@t, 4), '-', RIGHT(@t, 4));
END
GO

/* Número de documento con prefijo y ceros a la izquierda: ('OC-', 15, 6) -> OC-000015 */
CREATE OR ALTER FUNCTION compras.fn_FormatearNumero (@Prefijo VARCHAR(5), @Numero BIGINT, @Digitos INT)
RETURNS VARCHAR(20)
WITH SCHEMABINDING
AS
BEGIN
    RETURN CONCAT(@Prefijo, RIGHT(CONCAT(REPLICATE('0', @Digitos), @Numero), @Digitos));
END
GO

/* RQ27: cumplimiento de entrega comparando fecha esperada vs. fecha real */
CREATE OR ALTER FUNCTION compras.fn_Cumplimiento (@FechaEsperada DATE, @FechaRecepcion DATE)
RETURNS VARCHAR(10)
AS
BEGIN
    DECLARE @tolerancia INT = ISNULL(TRY_CAST(cfg.fn_Parametro('TOLERANCIA_DIAS_ENTREGA') AS INT), 0);
    DECLARE @diferencia INT = DATEDIFF(DAY, @FechaEsperada, @FechaRecepcion);
    RETURN CASE
               WHEN @diferencia >  @tolerancia THEN 'Retraso'
               WHEN @diferencia < -@tolerancia THEN 'Anticipada'
               ELSE 'ATiempo'
           END;
END
GO

/* Antigüedad de saldos para cuentas por pagar */
CREATE OR ALTER FUNCTION compras.fn_RangoAntiguedad (@FechaVencimiento DATE, @FechaCorte DATE)
RETURNS NVARCHAR(15)
WITH SCHEMABINDING
AS
BEGIN
    DECLARE @dias INT = DATEDIFF(DAY, @FechaVencimiento, @FechaCorte);
    RETURN CASE
               WHEN @dias <= 0  THEN N'Por vencer'
               WHEN @dias <= 30 THEN N'1-30'
               WHEN @dias <= 60 THEN N'31-60'
               WHEN @dias <= 90 THEN N'61-90'
               ELSE N'Más de 90'
           END;
END
GO

PRINT N'[OK] 04 - Funciones y secuencias.';
GO
