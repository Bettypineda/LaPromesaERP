# BancoSimulado.API — API externa de pagos bancarios

Servicio **independiente** del ERP (otro proceso, otro puerto, su propia clave y su propio almacenamiento).
El ERP lo consume por HTTP igual que consumiría la API de un banco real.

| Elemento | Valor |
|---|---|
| URL | http://localhost:5100 (Swagger en /swagger) |
| Seguridad | Encabezado `X-Api-Key` (user-secrets `Banco:ApiKey`, igual en ambos proyectos) |
| Transferir | `POST /api/v1/transferencias` |
| Consultar | `GET /api/v1/transferencias/{operacionId}` |
| Idempotencia | El mismo `operacionId` devuelve siempre la misma respuesta |

Casos de prueba: monto > Q50,000 → RECHAZADA; cuenta que termina en `0000` → RECHAZADA;
encabezado `X-Simular: rechazo | error | lento` para forzar rechazo, banco caído (503) o tiempo agotado.
