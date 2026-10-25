# memoria.md — La Promesa ERP

Memoria del proyecto para el agente de IA. Registrar solo decisiones y resultados verificados.

## 2026-10-22 — Inicio de la parte de Sara (Proveedores y Compras)
- Decisión: Stack 1 (SQL Server + ASP.NET Core + React), por consistencia con los módulos de Fernando (Inventarios y Ventas).
- Se creó la estructura base del repositorio según el documento del proyecto final.
- Pendiente: recibir repositorio y esquema de base de datos de Fernando para integrar Inventario, usuarios y roles.
- Pendiente: definir reglas del negocio, modelo de datos y flujo del proceso de Compras.

## 2026-10-22 — Proyecto backend creado
- La estudiante creó en Visual Studio la solución `backend/LaPromesa.Api/LaPromesa.Api.slnx` con el proyecto `backend/LaPromesa.Api/LaPromesa.Api` (ASP.NET Core Web API, .NET 10, controladores, OpenAPI).
- Configuración agregada: Swagger UI en `/swagger` (lee `/openapi/v1.json`), CORS para el frontend (`Frontend:Url`, por defecto http://localhost:5173), puertos 5000 (http) y 5001 (https), endpoint `GET /api/health`.
- Se retiró el ejemplo WeatherForecast de la plantilla. Archivos creados por error fuera del proyecto quedaron en `_to_delete/` (pueden borrarse).
- `ConnectionStrings:LaPromesaDb` va vacía en appsettings.json; el valor real se configura con user-secrets (no versionado).
- Pendiente de verificación por la estudiante: ejecutar en Visual Studio y abrir Swagger.

## 2026-10-22 — Base de datos completa v2 (PENDIENTE de ejecutar y verificar por la estudiante)
- Reemplaza la v1 (02_temporales_inventario / 03_proveedores_compras, movidos a `_to_delete/scripts_bd_version1/`).
- SQL Server 2022 en Docker, puerto 1435. Esquemas: cfg, inv (temporal de Fernando), compras, rpt, aud.
- Scripts 00–13 en `database/scripts`: base, parámetros, bitácora y registro de errores, inventario temporal,
  secuencias y funciones (NIT módulo 11, teléfono, cumplimiento RQ27, antigüedad), tablas con CHECK/FK/UNIQUE/ROWVERSION,
  vistas, triggers (auditoría, no eliminar, inmutables, transiciones de estado, recálculo de totales, saldos),
  procedimientos con TRY/CATCH + transacción (CRUD Proveedores y Compras, recepción integrada, CxP, pagos idempotentes),
  3 reportes en `rpt`, roles de mínimo privilegio y usuario de aplicación opcional (sin contraseña en el repo).
- `database/seed/01_datos_prueba.sql`: 6 categorías, 5 bodegas, 8 productos, 7 proveedores, 8 órdenes en todos los estados,
  recepciones a tiempo/retraso/anticipada, pagos (cheque, efectivo, transferencia simulada). Creado mediante los SP.
- `database/tests/01_pruebas_reglas_negocio.sql`: 29 pruebas negativas + verificaciones de integridad.
- Reglas: `docs/reglas-negocio/RN_proveedores_compras.md` (RN-PC-01 a 23). Errores y mapeo HTTP: `database/README.md`.
- Pendiente: ejecutar 00_ejecutar_todo.sql en Modo SQLCMD y luego las pruebas; registrar aquí el resultado real.

## 2026-10-23 — Backend escrito (PENDIENTE de compilar y probar por la estudiante)
- `database/scripts/14_autenticacion_temporal.sql`: esquema seg (Roles, Usuarios, RefreshTokens) + SP de catálogos. Incluido en 00_ejecutar_todo.
- LaPromesa.Api (.NET 10): Dapper + SqlClient, capas Controlador → Servicio → Repositorio → SP; JWT (15 min) + refresh (7 días, rotación,
  detección de reutilización, logout); bloqueo tras 5 intentos; roles Administrador/Compras/Gerente/Bodega/Tesoreria/Consulta;
  errores SQL 51xxx–54xxx mapeados a 400/404/409 (ProblemDetails); Swagger con Authorize.
- Endpoints: /api/auth, /api/proveedores, /api/categorias-proveedor, /api/ordenes-compra (+aprobar, anular, recepciones),
  /api/recepciones, /api/cuentas-por-pagar (+pagos), /api/pagos (pendientes, reintentar), /api/reportes (3, JSON o CSV), /api/catalogos.
- BancoSimulado.Api (puerto 5100): servicio independiente con X-Api-Key, idempotencia por operacionId, reglas deterministas y X-Simular.
- Secretos: `scripts/Secretitos.ps1` (user-secrets; nada en el repositorio).

## 2026-10-23 — Base de datos VERIFICADA en SSMS (localhost,1435)
- 00_ejecutar_todo.sql (Modo SQLCMD): 01–14 y datos de prueba en [OK], "base de datos instalada correctamente".
- Correcciones aplicadas: variables @nit/@tel chocaban con @Nit/@Telefono por la intercalación CI (renombradas a @nitFinal/@telFinal);
  falta de ';' antes de THROW en sp_Pago_Confirmar.
- tests/01_pruebas_reglas_negocio.sql: 29 pruebas, 29 pasaron, 0 fallaron; verificación de integridad sin filas.
- tests/02_verificar_objetos.sql (2026-10-23 20:32): 92 objetos esperados de los scripts 01–14, 0 faltantes
  (19 tablas, 7 vistas, 31 procedimientos, 7 funciones, 23 triggers, 5 secuencias); 6 esquemas, 3 roles de BD, 7 parámetros.
  Datos: 7 proveedores, 8 órdenes, 5 recepciones, 5 cuentas por pagar, 3 pagos, 7 movimientos de kardex, 77 registros de bitácora.
  Pendiente: seg.Usuarios = 0 (los crea el backend al iniciar) y script 13 opcional no ejecutado.

## 2026-10-23 — Backend reestructurado según las guías del ingeniero (PENDIENTE compilar y probar)
- Revisadas las guías en Downloads\desarrolloweb (1, 2, 4.1, 4.2, 5.1–5.5, 6, 7, 8.1, 8.2, Actividad Semana 4, Postman).
- Decisión de la estudiante: estructura igual al ingeniero; los procedimientos almacenados conservan sus nombres actuales.
- Nueva solución `backend/LaPromesa/LaPromesa.slnx`: LaPromesa.API, .Entidades, .DTO, .Datos, .Negocio, .Utilidades
  (referencias según guía 4.1) + BancoSimulado.API (servicio externo independiente).
- ADO.NET (SqlConnection/SqlCommand/SqlDataReader + SP), ConexionSQL estática, RespuestaApi<T>, rutas tipo
  ConsultarProveedores / BuscarProveedor/{codigo} / AgregarProveedor / EditarProveedor / EliminarProveedor/{codigo} (lógico).
- Script 14 ampliado con procedimientos seg.sp_Usuario_* y seg.sp_RefreshToken_* (pendiente ejecutar en SSMS).
- La versión anterior `backend/LaPromesa.Api` queda obsoleta; moverla a _to_delete cuando Visual Studio esté cerrado.
- 2026-10-23 22:56 VERIFICADO: script 14 ejecutado en SSMS ([OK] 14 - Procedimientos de autenticación).
  Los 7 proyectos de la solución nueva COMPILAN en Visual Studio 2026 (.NET 10); LaPromesa.API arranca en
  http://localhost:5000/swagger con las rutas del ingeniero; perfil de inicio "API + Banco simulado" (LaPromesa.slnLaunch).
  Corrección: Program.cs ahora ignora ConexionSQL vacío en appsettings y usa la cadena de user-secrets.
  Pendiente: probar login y endpoints en Swagger/Postman.

## 2026-10-24 — Pruebas Postman completas
- Login verificado (admin, 200, tokens y rol). Usuarios demo creados.
- Colección `docs/postman/LaPromesa_ProveedoresCompras.postman_collection.json` + entorno local importados en Postman.
- 1.ª corrida: 18 fallos en cascada. Causa: `@RowVersion` en NULL se enviaba como nvarchar ("Implicit conversion from nvarchar to binary").
  Corrección: `AccesoDatos.Parametro` fuerza `SqlDbType.Binary(8)` para parámetros RowVersion/byte[].
- Scripts post-response de la colección protegidos contra `datos = null` (un fallo ya no detiene la corrida).
- 2.ª corrida (Runner, entorno "La Promesa ERP - Local"): **74 requests, 177 pruebas, 0 fallos, 0 errores**.

## 2026-10-24 — Frontend React completo (frontend/LaPromesa.Web)
- Vite + React 19 + TypeScript, Axios, Bootstrap 5, Bootstrap Icons, React Router (estructura de las guías 7/8.x: components, pages, services, interfaces).
- Sesión JWT: access token en cada petición, renovación automática con refresh token ante 401, cierre de sesión revoca el refresh.
- Menú y botones por rol (mismas combinaciones que RolesSistema.cs). Rutas protegidas.
- Pantallas: Inicio por rol, Proveedores (consultar/agregar/editar/inactivar con motivo/reactivar/detalle), Órdenes de compra (consultar/crear/editar/aprobar/anular/detalle con recorrido e historial), Recibir mercadería (proceso integrado), Recepciones, Cuentas por pagar + pago (transferencia por API bancaria, cheque, efectivo; operacionId idempotente), Pagos en revisión, 3 reportes con CSV e impresión.
- Validaciones en cliente iguales al backend (NIT módulo 11, teléfono GT, contado/crédito, banco+cuenta, motivo ≥ 10, cantidades ≤ pendiente).
- Ejecutar: doble clic en `iniciar-frontend.bat` (o `npm install` + `npm run dev`) → http://localhost:5173. Compila sin errores (`npm run build`).

## 2026-10-24 — Manuales, evidencias y pruebas E2E
- Pruebas E2E reales (frontend → API → SQL Server → banco) con Playwright + Edge: `frontend/LaPromesa.Web/e2e/` (doble clic en ejecutar-pruebas-e2e.bat).
  Resultado: 57/57 casos (validaciones, permisos por rol, refresh token, proceso integrado por 4 roles, pagos aprobado/rechazado, API del banco). 46 capturas en docs/evidencias/capturas.
- Re-ejecutado en SSMS: 01_pruebas_reglas_negocio 29/29; 02_verificar_objetos sin faltantes. Postman Runner: 177/177.
- Correcciones encontradas por las pruebas: mensajes de validación de los DTO en español; al cerrar sesión el siguiente usuario entra a Inicio (no a la página anterior); Docker se había detenido (login colgado).
- Documentos: docs/manuales/Manual_Tecnico_Proveedores_Compras.docx, docs/manuales/Manual_Usuario_Proveedores_Compras.docx, docs/evidencias/Evidencia_Compras_Prove.docx.
- Diagramas (Mermaid, fuente .mmd + .png): arquitectura, ER, proceso de compras, secuencia de pago con el banco, flujo JWT en docs/diagramas.
