# La Promesa ERP — Distribuidora Comercial

Sistema ERP web académico para la distribuidora comercial **La Promesa**.
Proyecto final del curso Desarrollo Web — Universidad Mariano Gálvez, Centro Universitario Cuilapa, Santa Rosa.

## Stack (Stack 1)
| Capa | Tecnología |
|---|---|
| Base de datos | SQL Server 2022 (Docker) |
| Backend | C# — ASP.NET Core Web API |
| Frontend | React (JavaScript/TypeScript) |
| Pruebas de API | Postman / Swagger |
| Control de versiones | Git y GitHub |

## Estructura
```
backend/      API, reglas del negocio, acceso a datos, autenticación y validaciones
frontend/     Interfaz, navegación, formularios y consumo de la API
database/     Scripts de creación (scripts/) y datos de prueba (seed/)
docker/       Configuración del contenedor de SQL Server
docs/         Diagramas, reglas del negocio, manuales, evidencias y colección Postman
AGENTS.md     Instrucciones para el agente de IA
memoria.md    Memoria del proyecto (decisiones, avances y pruebas verificadas)
.ai/skills/   Habilidades del agente (SKILL.md por módulo)
```

## Módulos y responsables
| Integrante | Módulos | Proceso integrado | API externa |
|---|---|---|---|
| Fernando | Inventarios, Ventas | (por definir) | (por definir) |
| Sara | Proveedores, Compras | Orden de compra → recepción → inventario → cuenta por pagar → pago | Pagos bancarios (servicio simulado independiente) |
| (pendiente) | (pendiente) | (pendiente) | (pendiente) |

## Instalación y ejecución

Requisitos: Docker Desktop, SQL Server Management Studio, .NET 10 SDK (Visual Studio 2022/2026), Node.js 20+.

1. **Base de datos**: copiar `.env.example` a `.env`, definir `MSSQL_SA_PASSWORD` y ejecutar `docker compose -f docker/docker-compose.yml up -d` (puerto 1435).
   En SSMS abrir `database/scripts/00_ejecutar_todo.sql`, activar **Modo SQLCMD** y ejecutar (F5). Verificar con `database/tests/`.
2. **Backend**: configurar secretos con `scripts/configurar-secretos.ps1` (o `appsettings.Development.local.json`, ignorado por Git).
   Abrir `backend/LaPromesa/LaPromesa.slnx`, perfil **API + Banco simulado**, F5 → API `http://localhost:5000/swagger`, banco `http://localhost:5100/swagger`.
3. **Frontend**: `cd frontend/LaPromesa.Web`, `npm install`, `npm run dev` → `http://localhost:5173` (o doble clic en `iniciar-frontend.bat`).
4. **Pruebas**: colección Postman en `docs/postman`; pruebas E2E con `frontend/LaPromesa.Web/e2e/ejecutar-pruebas-e2e.bat`.

## Documentación

| Documento | Ubicación |
|---|---|
| Manual técnico (incluye APIs y API externa) | `docs/manuales/` |
| Manual de usuario | `docs/manuales/` |
| Evidencias de pruebas y capturas | `docs/evidencias/` |
| Diagramas (arquitectura, ER, procesos) | `docs/diagramas/` |
| Reglas del negocio | `docs/reglas-negocio/` |
| Base de datos (scripts y códigos de error) | `database/README.md` |
