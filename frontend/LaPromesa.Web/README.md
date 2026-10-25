# LaPromesa.Web — Frontend de Proveedores y Compras

React 19 + TypeScript (Vite), Axios, Bootstrap 5, Bootstrap Icons y React Router.
Estructura del curso (guías 7, 8.1 y 8.2): `components`, `pages`, `services`, `interfaces`.

## Requisitos
- Node.js 20 o superior (`node --version`)
- Backend `LaPromesa.API` encendido en `http://localhost:5000` (y `BancoSimulado.API` en el 5100 para transferencias)

## Ejecutar
```bash
npm install      # solo la primera vez
npm run dev      # abre http://localhost:5173
```
En Windows también puede dar doble clic a `iniciar-frontend.bat`.

La URL del backend está en `.env.development` (`VITE_API_URL`). El puerto 5173 es el que el backend permite en CORS.

## Estructura
| Carpeta | Contenido |
|---|---|
| `src/interfaces` | Tipos de las respuestas y peticiones (iguales a los DTO del backend) |
| `src/services` | `api.ts` (Axios + JWT + renovación automática con refresh token) y un servicio por controlador |
| `src/context` | Sesión (`AuthContext`) y avisos (`AvisosContext`) |
| `src/components` | Menú lateral, rutas protegidas por rol, paginación, modales, estados |
| `src/pages` | Una página por pantalla (consultar, agregar, editar, detalle) |
| `src/utils` | Formatos (Q, fechas), validaciones (NIT módulo 11, teléfono), roles y errores |

## Pantallas
- **Inicio**: resumen y pendientes según el rol.
- **Proveedores** (CRUD): consultar con filtros, orden y paginación; agregar; editar (con `rowVersion`); inactivar con motivo (eliminación lógica) y reactivar; detalle con órdenes, cuentas y cumplimiento.
- **Órdenes de compra** (CRUD): consultar, crear con líneas, editar (solo pendientes), aprobar, anular con motivo, detalle con recorrido e historial.
- **Proceso integrado**: recibir mercadería → nota de compra + inventario + cuenta por pagar.
- **Cuentas por pagar**: consultar y pagar (transferencia por la API bancaria externa, cheque o efectivo) con `operacionId` idempotente; pagos en revisión con reintento.
- **Reportes**: compras por proveedor, cumplimiento de entregas y antigüedad de saldos; CSV e impresión.

## Seguridad en el cliente
- El access token (15 min) se envía en `Authorization: Bearer`. Al recibir 401 se renueva una sola vez con el refresh token; si falla, vuelve al login.
- El menú y los botones se muestran según el rol (mismas combinaciones que `RolesSistema.cs`); el backend vuelve a validar cada permiso.
- Las validaciones de formularios replican las del backend y la base de datos.
