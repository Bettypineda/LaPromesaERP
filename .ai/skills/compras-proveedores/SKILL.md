---
name: compras-proveedores
description: Cómo desarrollar y probar los módulos Proveedores y Compras de La Promesa ERP (ASP.NET Core + SQL Server + React).
---

# Skill: Proveedores y Compras

## Cuándo usarla
Al crear o modificar cualquier parte de los módulos Proveedores y Compras, su proceso integrado, sus reportes o la integración de pagos bancarios.

## Pasos
1. Leer `AGENTS.md` y `memoria.md`.
2. Revisar el modelo en `docs/diagramas` y las reglas en `docs/reglas-negocio`.
3. Base de datos: scripts en `database/scripts` (esquema) y `database/seed` (datos de prueba).
4. Backend: Entidad → Repositorio → Servicio → Controlador; validar reglas del negocio en el servicio.
5. Permisos: proteger cada endpoint por rol en el backend.
6. Frontend: pantallas con búsqueda por texto, filtros combinados, ordenamiento y mensajes claros.
7. Pruebas: agregar solicitudes de éxito y error a la colección de Postman en `docs/postman`.
8. Actualizar `memoria.md` con lo verificado.

## Proceso integrado (Compras)
Orden de compra (Borrador) → Aprobada → Recibida parcial/total (entrada a inventario y costo) → Cuenta por pagar → Pagada (API de pagos bancarios).
