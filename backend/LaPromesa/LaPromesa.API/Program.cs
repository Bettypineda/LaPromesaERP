using System.Text;
using LaPromesa.API.Configuracion;
using LaPromesa.DTO.DTO;
using LaPromesa.Negocio.Servicios;
using LaPromesa.Utilidades.Configuracion;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);
// Configuración local de esta computadora (ignorada por Git): tiene prioridad sobre user-secrets
builder.Configuration.AddJsonFile($"appsettings.{builder.Environment.EnvironmentName}.local.json", optional: true, reloadOnChange: false);

// ---------------- Cadena de conexión (user-secrets; nunca en el repositorio) ----------------
ConexionSQL.CadenaConexion = new[]
    {
        builder.Configuration.GetConnectionString("ConexionSQL"),
        builder.Configuration.GetConnectionString("LaPromesaDb")
    }.FirstOrDefault(c => !string.IsNullOrWhiteSpace(c)) ?? string.Empty;
if (string.IsNullOrWhiteSpace(ConexionSQL.CadenaConexion))
    throw new InvalidOperationException("No se encontró la cadena de conexión ConexionSQL (configúrela con dotnet user-secrets).");

// ---------------- JWT ----------------
ConfiguracionJwt.Emisor = builder.Configuration["Jwt:Issuer"] ?? "LaPromesaERP";
ConfiguracionJwt.Audiencia = builder.Configuration["Jwt:Audience"] ?? "LaPromesaERP.Web";
ConfiguracionJwt.MinutosAccessToken = builder.Configuration.GetValue("Jwt:AccessMinutes", 15);
ConfiguracionJwt.DiasRefreshToken = builder.Configuration.GetValue("Jwt:RefreshDays", 7);
ConfiguracionJwt.Clave = builder.Configuration["Jwt:Key"] ?? string.Empty;
if (Encoding.UTF8.GetByteCount(ConfiguracionJwt.Clave) < 32)
    throw new InvalidOperationException("Falta Jwt:Key (mínimo 32 caracteres) en user-secrets.");

// ---------------- API bancaria externa ----------------
ConfiguracionBanco.UrlBase = builder.Configuration["Banco:BaseUrl"] ?? "http://localhost:5100";
ConfiguracionBanco.ApiKey = builder.Configuration["Banco:ApiKey"] ?? string.Empty;
ConfiguracionBanco.TimeoutSegundos = builder.Configuration.GetValue("Banco:TimeoutSegundos", 10);

// ---------------- Servicios ----------------
builder.Services.AddControllers()
    .ConfigureApiBehaviorOptions(opciones =>
    {
        // Errores de validación de los DTO con el mismo formato RespuestaApi
        opciones.InvalidModelStateResponseFactory = contexto =>
        {
            var errores = contexto.ModelState
                .Where(e => e.Value?.Errors.Count > 0)
                .ToDictionary(e => e.Key, e => e.Value!.Errors.Select(x => x.ErrorMessage).ToArray());
            return new BadRequestObjectResult(new RespuestaApi<Dictionary<string, string[]>>
            {
                Exito = false,
                Mensaje = "Datos inválidos. Revise los campos marcados.",
                Datos = errores,
                Detalle = string.Join(" ", errores.SelectMany(e => e.Value))
            });
        };
    });

builder.Services.AddOpenApi(o => o.AddDocumentTransformer<SeguridadOpenApi>());

// CORS para permitir conexión desde React
var urlFrontend = builder.Configuration["Frontend:Url"] ?? "http://localhost:5173";
builder.Services.AddCors(options =>
{
    options.AddPolicy("PermitirFrontend", policy =>
    {
        policy
            .WithOrigins(urlFrontend.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            .AllowAnyHeader()
            .AllowAnyMethod()
            .WithExposedHeaders("Content-Disposition");
    });
});

// Autenticación JWT
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o =>
    {
        o.MapInboundClaims = true;
        o.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = ConfiguracionJwt.Emisor,
            ValidateAudience = true,
            ValidAudience = ConfiguracionJwt.Audiencia,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(ConfiguracionJwt.Clave)),
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromSeconds(30)
        };
        o.Events = new JwtBearerEvents
        {
            OnChallenge = async contexto =>
            {
                contexto.HandleResponse();
                contexto.Response.StatusCode = 401;
                await contexto.Response.WriteAsJsonAsync(new RespuestaApi<object>
                {
                    Exito = false,
                    Mensaje = contexto.AuthenticateFailure is SecurityTokenExpiredException
                        ? "El access token expiró. Renueve con /api/Autenticacion/RenovarToken."
                        : "No autenticado. Envíe el encabezado Authorization: Bearer <accessToken>."
                });
            },
            OnForbidden = async contexto =>
            {
                contexto.Response.StatusCode = 403;
                await contexto.Response.WriteAsJsonAsync(new RespuestaApi<object>
                {
                    Exito = false,
                    Mensaje = "Acceso denegado: su rol no tiene permiso para esta operación."
                });
            }
        };
    });
builder.Services.AddAuthorization();

var app = builder.Build();

// OpenAPI + Swagger
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.UseSwaggerUI(options =>
    {
        options.SwaggerEndpoint("/openapi/v1.json", "La Promesa ERP API v1");
        options.DocumentTitle = "La Promesa ERP API";
    });

    // Usuarios demo (uno por rol) con la contraseña de user-secrets "Seed:PasswordDemo"
    var claveDemo = app.Configuration["Seed:PasswordDemo"];
    if (!string.IsNullOrWhiteSpace(claveDemo) && claveDemo.Length >= 8)
    {
        try
        {
            var creados = new AutenticacionNegocio().CrearUsuariosDemo(claveDemo);
            if (creados > 0) app.Logger.LogInformation("Se crearon {Cantidad} usuarios demo.", creados);
        }
        catch (Exception ex)
        {
            app.Logger.LogError(ex, "No se pudieron crear los usuarios demo (¿se ejecutó 14_autenticacion_temporal.sql?).");
        }
    }
}
else
{
    app.UseHsts();
    app.UseHttpsRedirection();
}

// Permitir comunicación con React
app.UseCors("PermitirFrontend");
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.Run();
