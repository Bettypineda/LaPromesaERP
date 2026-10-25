# AGENTS.md — La Promesa ERP

Instrucciones para el agente de IA (Copilot / Codex) que trabaja en este repositorio.

## Contexto
- Sistema ERP web académico para la distribuidora comercial **La Promesa** (Guatemala).
- Stack 1: SQL Server 2022 (Docker) + ASP.NET Core Web API (C#) + React.
- Equipo de 3 integrantes; cada uno desarrolla 2 módulos, 1 proceso integrado, 3 reportes y 1 API externa.
- Módulos de Sara: **Proveedores** y **Compras**. Inventarios y Ventas pertenecen a Fernando: NO modificarlos sin autorización.

## Reglas de trabajo
1. Leer `memoria.md` antes de empezar y actualizarlo SOLO con resultados verificados.
2. Presentar un plan breve antes de cambiar archivos; trabajar por etapas pequeñas y detenerse para revisión.
3. Respetar la estructura de carpetas del README; no crear carpetas paralelas.
4. Backend por capas: Entidad → Repositorio → Servicio → Controlador; DTOs y validaciones con mensajes comprensibles.
5. Seguridad: contraseñas con hash del framework; JWT (access + refresh), permisos por rol verificados en el backend; consultas parametrizadas.
6. No escribir credenciales reales en el código ni en archivos versionados; usar `.env` / user-secrets y mantener `.env.example`.
7. Eliminaciones como anulación o inactivación con trazabilidad (fecha, usuario, motivo).
8. Datos de prueba ficticios (al menos 5 registros por catálogo), adaptados a Guatemala (GTQ, NIT, departamentos).
9. Toda API externa debe ser un servicio HTTP independiente del backend principal, con manejo de éxito y error.
10. No instalar dependencias sin justificarlas; no hacer commit/push sin autorización del estudiante.

## Tablas temporales
Las tablas de inv.* (Bodegas, Productos, Existencias, MovimientosInventario) de inventario creadas para probar el proceso de Compras son
**temporales** y deben reemplazarse por las del módulo de Inventarios de Fernando al integrar.

## Base de datos (reglas para el agente)
- Toda escritura pasa por procedimientos `compras.sp_*`; la API no hace INSERT/UPDATE/DELETE directos.
- No eliminar triggers ni constraints para "hacer pasar" una prueba: corregir la causa.
- Errores 51xxx→400, 52xxx→404, 53xxx/54xxx→409 (ver `database/README.md`).
- Scripts siempre repetibles (IF NOT EXISTS / CREATE OR ALTER / MERGE).
