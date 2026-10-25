# Reglas de negocio — Proveedores y Compras (Sara)

Cada regla indica **dónde se garantiza**: API (validación del backend), SP (procedimiento almacenado), TRG (trigger), CHK (restricción de tabla). Las reglas críticas se validan en varias capas.

| ID | Regla | Garantía |
|---|---|---|
| RN-PC-01 | El NIT del proveedor es obligatorio, único y debe cumplir el dígito verificador de la SAT (módulo 11). | API, SP, CHK, UNIQUE |
| RN-PC-02 | Un proveedor de **Contado** tiene 0 días de crédito y límite 0; uno de **Crédito** tiene entre 1 y 180 días. | API, SP, CHK |
| RN-PC-03 | Un proveedor no se elimina: se **inactiva** con fecha, usuario y motivo (mín. 10 caracteres); puede reactivarse. | SP, TRG, CHK |
| RN-PC-04 | No se inactiva un proveedor con órdenes abiertas (Pendiente, Aprobada o Parcial). | SP, TRG |
| RN-PC-05 | Un proveedor **inactivo** no puede recibir nuevas órdenes de compra ni editarse. | SP, TRG |
| RN-PC-06 | El NIT no se puede cambiar si el proveedor ya tiene órdenes de compra. | TRG |
| RN-PC-07 | Una orden de compra requiere proveedor activo, bodega activa, al menos una línea, productos activos sin repetir, cantidades y costos mayores que cero, y fecha esperada ≥ fecha de orden. | API, SP, CHK |
| RN-PC-08 | Subtotal, IVA (12 %) y total los calcula la base de datos, nunca el frontend. | TRG |
| RN-PC-09 | Ciclo de estados: Pendiente → Aprobada → Parcial → Recibida; Anulada solo desde Pendiente o Aprobada sin recepciones. No se permiten otros saltos. | SP, TRG |
| RN-PC-10 | Una orden solo se **edita** en estado Pendiente; aprobada, sus datos comerciales quedan congelados. | SP, TRG |
| RN-PC-11 | Quien crea una orden no puede aprobarla (segregación de funciones, configurable). | SP |
| RN-PC-12 | Al aprobar, el saldo por pagar más lo comprometido y la nueva orden no puede superar el límite de crédito del proveedor. | SP |
| RN-PC-13 | Solo se recibe mercadería de órdenes Aprobadas o Parciales, sin exceder la cantidad pendiente de cada línea. | SP, CHK, TRG |
| RN-PC-14 | Cada recepción exige factura del proveedor, que no puede repetirse para el mismo proveedor. | SP, UNIQUE |
| RN-PC-15 | La recepción (nota de compra) es un documento definitivo: no se modifica ni elimina (RQ25). | TRG |
| RN-PC-16 | Cada recepción se clasifica según la fecha esperada: A tiempo, Retraso o Anticipada (RQ27). | SP, función |
| RN-PC-17 | Cada recepción aumenta existencias, registra kardex y recalcula costo promedio, en la misma transacción (RQ04). | SP |
| RN-PC-18 | Cada recepción genera una cuenta por pagar que vence según los días de crédito pactados en la orden. | SP |
| RN-PC-19 | Un pago no puede exceder el saldo disponible (saldo menos pagos en proceso). | SP, TRG |
| RN-PC-20 | Las transferencias se procesan con la API bancaria con un identificador de operación único: los reintentos no duplican pagos; tras 3 intentos fallidos el pago queda Rechazado. | SP, UNIQUE |
| RN-PC-21 | Un pago Aprobado o Rechazado es definitivo; el saldo de la cuenta solo disminuye por pagos aprobados. | TRG, CHK |
| RN-PC-22 | Toda creación o modificación queda en bitácora con usuario, fecha y datos antes/después; la bitácora es de solo lectura. | TRG |
| RN-PC-23 | Si dos usuarios editan el mismo registro, el segundo es rechazado (concurrencia optimista con RowVersion). | SP |
