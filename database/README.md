# Base de datos — La Promesa ERP (Proveedores y Compras)

Motor: **SQL Server 2022** en Docker (`localhost,1435`) · Base: **LaPromesaERP** · Intercalación: `Modern_Spanish_CI_AS`

## Instalación

1. Abrir `scripts/00_ejecutar_todo.sql` en SSMS (conectado a `localhost,1435`).
2. Activar **Consulta → Modo SQLCMD**.
3. Verificar la ruta en `:setvar RutaBD` y presionar **F5**.
4. Ejecutar `tests/01_pruebas_reglas_negocio.sql` → todas las pruebas deben decir **PASÓ** y la última consulta (integridad) debe devolver 0 filas.

Todos los scripts son **repetibles**. `13_usuario_aplicacion.sql` es opcional y se ejecuta aparte con `sqlcmd` (la contraseña nunca se guarda en el repositorio).

## Estructura

| Script | Contenido |
|---|---|
| 01 | Base de datos, `READ_COMMITTED_SNAPSHOT` (lecturas sin bloqueos) |
| 02 | Esquemas `cfg`, `inv`, `compras`, `rpt`, `aud`; parámetros; bitácora; registro de errores |
| 03 | Inventario **temporal** (`inv.*`, módulo de Fernando) |
| 04 | Secuencias de numeración y funciones (NIT módulo 11, teléfono, cumplimiento RQ27, antigüedad) |
| 05 | Tablas con PK, FK, UNIQUE, CHECK, auditoría, `ROWVERSION` e índices |
| 06 | Vistas para pantallas y reportes |
| 07 | Triggers de auditoría, no-eliminación, inmutabilidad y reglas |
| 08–10 | Procedimientos con `TRY/CATCH`, transacciones y `XACT_ABORT` |
| 11 | 3 reportes con filtros (resumen, detalle y totales) |
| 12–13 | Roles de mínimo privilegio y usuario de la aplicación |

## Objetos principales

**Tablas (`compras`)**: CategoriasProveedor, Proveedores, OrdenesCompra, OrdenesCompraDetalle, OrdenesCompraHistorial, Recepciones, RecepcionesDetalle, CuentasPorPagar, PagosProveedor.

**Procedimientos para la API**

| Módulo | Procedimientos |
|---|---|
| Categorías | `sp_Categoria_Listar`, `sp_Categoria_Crear` |
| Proveedores | `sp_Proveedor_Listar`, `_Obtener`, `_Crear`, `_Actualizar`, `_Inactivar`, `_Reactivar` |
| Órdenes de compra | `sp_OrdenCompra_Listar`, `_Obtener`, `_Crear`, `_Actualizar`, `_Aprobar`, `_Anular` |
| Recepciones | `sp_Recepcion_Registrar`, `_Listar`, `_Obtener` |
| Cuentas por pagar | `sp_CuentaPagar_Listar`, `_Obtener` |
| Pagos (API bancaria) | `sp_Pago_Iniciar`, `_Confirmar`, `_RegistrarIntento`, `_ListarPendientes` |
| Reportes (`rpt`) | `sp_ComprasPorProveedor`, `sp_CumplimientoProveedores`, `sp_CuentasPorPagarVencimiento` |

El detalle de órdenes y recepciones se envía como **JSON**:
`[{"idProducto":1,"cantidad":10,"costoUnitario":4.25}]` y `[{"idDetalle":1,"cantidad":5}]`.

## Flujo del proceso integrado

```
Orden de compra (Pendiente) ──aprobar──▶ Aprobada ──recibir parcial──▶ Parcial ──recibir resto──▶ Recibida
        │                                  │
        └──────────anular (motivo)─────────┴──▶ Anulada (solo sin recepciones)

Cada recepción = nota de compra definitiva ──▶ existencias + kardex (inventario)
                                           ──▶ cuenta por pagar (vence según días de crédito)
                                           ──▶ pago: Cheque/Efectivo (inmediato) o
                                               Transferencia vía API bancaria (Pendiente → Aprobado/Rechazado)
```

## Catálogo de errores (para mapear a HTTP en el backend)

| Rango | Significado | HTTP |
|---|---|---|
| 51xxx | Validación de datos | 400 Bad Request |
| 52xxx | Registro no existe | 404 Not Found |
| 53xxx | Regla de negocio / estado no permitido | 409 Conflict |
| 54xxx | Concurrencia (otro usuario modificó) | 409 Conflict |
| < 50000 | Error técnico de SQL Server (queda en `aud.ErroresBD`) | 500 |

| Código | Mensaje resumido |
|---|---|
| 51000 | Paginación, orden o filtro inválido |
| 51001 | Usuario de la operación obligatorio |
| 51002 | RowVersion obligatorio para actualizar |
| 51010 | Nombre de proveedor inválido |
| 51011 | NIT inválido (dígito verificador) |
| 51012 | Teléfono inválido |
| 51013 | Correo inválido |
| 51014 | Tipo de pago inválido |
| 51015 | Días de crédito inválidos para el tipo de pago |
| 51016 | Límite de crédito inválido |
| 51017 | Motivo obligatorio (mín. 10 caracteres) |
| 51018 | Categoría inválida o inactiva |
| 51019 | Datos bancarios incompletos |
| 51020 | Detalle JSON inválido o vacío |
| 51021 | Producto inexistente o inactivo |
| 51022 | Cantidad o costo no positivos |
| 51023 | Producto/línea repetida |
| 51024 | Fechas inválidas |
| 51025 | Bodega inválida o inactiva |
| 51030 | Cantidad recibida excede lo pendiente |
| 51031 | Línea no pertenece a la orden |
| 51032 | Número de factura obligatorio |
| 51040 | Monto de pago inválido |
| 51041 | Datos de pago incompletos (método, cheque, banco, referencia) |
| 51050 | Parámetros de reporte inválidos |
| 52001–52005 | No existe: proveedor, orden, recepción, cuenta por pagar, pago |
| 53001 | Eliminación física no permitida / registro de solo lectura |
| 53002 | NIT duplicado |
| 53003 | Proveedor inactivo no editable |
| 53004 | Proveedor ya activo / ya inactivo |
| 53005 | Proveedor con órdenes abiertas no se inactiva |
| 53006 | Proveedor inactivo no recibe órdenes |
| 53007 | Orden no editable (solo Pendiente) |
| 53008 | Límite de crédito excedido |
| 53009 | Orden no está en estado para recibir |
| 53010 | Transición de estado no permitida |
| 53011 | Factura del proveedor duplicada |
| 53012 | Orden con recepciones no se anula |
| 53013 | Pago excede el saldo disponible |
| 53014 | OperacionId ya usado con otros datos |
| 53015 | Pago definitivo no modificable |
| 53016 | Nota de compra (recepción) inmutable |
| 53017 | Quien crea la orden no la aprueba |
| 53018 | Cuenta por pagar ya pagada |
| 53019 | Registro en estado final no modificable |
| 53020 | NIT no modificable con documentos |
| 53021 | Categoría duplicada |
| 54001 | Concurrencia: registro modificado por otro usuario |

## Parámetros (`cfg.Parametros`)

`TASA_IVA` (0.12), `DIAS_CREDITO_MAX` (180), `TOLERANCIA_DIAS_ENTREGA` (0), `OC_APROBADOR_DISTINTO` (1), `OC_MAX_LINEAS` (100), `PAGO_MAX_INTENTOS` (3), `MONEDA` (GTQ).

## Integración pendiente

- `inv.*` son tablas temporales. Al recibir el esquema de Fernando se reemplaza solo el bloque **INVENTARIO** de `compras.sp_Recepcion_Registrar` y las FK hacia productos/bodegas.
- El usuario de cada operación (`@Usuario`) lo enviará el backend desde el JWT; la base lo guarda en auditoría mediante `SESSION_CONTEXT`.
