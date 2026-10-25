using Microsoft.AspNetCore.OpenApi;
using Microsoft.OpenApi;

namespace LaPromesa.API.Configuracion
{
    /// <summary>Agrega el esquema Bearer (JWT) al documento OpenAPI para usar "Authorize" en Swagger UI.</summary>
    public sealed class SeguridadOpenApi : IOpenApiDocumentTransformer
    {
        public Task TransformAsync(OpenApiDocument document, OpenApiDocumentTransformerContext context, CancellationToken cancellationToken)
        {
            document.Info.Title = "La Promesa ERP - Proveedores y Compras";
            document.Info.Description = "1) POST /api/Autenticacion/IniciarSesion  2) copie datos.accessToken  3) botón Authorize.";

            document.Components ??= new OpenApiComponents();
            document.Components.SecuritySchemes ??= new Dictionary<string, IOpenApiSecurityScheme>();
            document.Components.SecuritySchemes["Bearer"] = new OpenApiSecurityScheme
            {
                Type = SecuritySchemeType.Http,
                Scheme = "bearer",
                BearerFormat = "JWT",
                In = ParameterLocation.Header,
                Description = "Pegue solo el accessToken (sin la palabra Bearer)."
            };

            document.Security ??= [];
            document.Security.Add(new OpenApiSecurityRequirement
            {
                [new OpenApiSecuritySchemeReference("Bearer", document)] = []
            });
            return Task.CompletedTask;
        }
    }
}
