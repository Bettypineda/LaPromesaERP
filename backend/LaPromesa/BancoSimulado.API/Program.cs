// =====================================================================
//  BANCO SIMULADO GT — API externa de pagos bancarios (servicio independiente)
//  -------------------------------------------------------------------
//  Simula la API de un banco para transferencias a proveedores.
//  Es un proceso aparte del ERP: se ejecuta en su propio puerto (5100),
//  exige clave de API (X-Api-Key) y guarda sus transferencias en un archivo.
//
//  Reglas de la simulación (deterministas para poder probarlas):
//   - Monto mayor al límite por transferencia (Q50,000)  -> RECHAZADA
//   - Cuenta destino que termina en "0000"                -> RECHAZADA (cuenta inexistente)
//   - Encabezado X-Simular: rechazo | error | lento       -> fuerza el caso
//       error = responde 503 (banco caído); lento = tarda 15 s (timeout en el ERP)
//   - El mismo operacionId devuelve SIEMPRE la misma respuesta (idempotencia)
// =====================================================================
using System.Collections.Concurrent;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

var builder = WebApplication.CreateBuilder(args);
// Configuración local de esta computadora (ignorada por Git): tiene prioridad sobre user-secrets
builder.Configuration.AddJsonFile($"appsettings.{builder.Environment.EnvironmentName}.local.json", optional: true, reloadOnChange: false);
builder.Services.AddOpenApi();
builder.Services.ConfigureHttpJsonOptions(o => o.SerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase);
builder.Services.AddSingleton<AlmacenTransferencias>();

var apiKey = builder.Configuration["Banco:ApiKey"];
if (string.IsNullOrWhiteSpace(apiKey) || apiKey.Length < 16)
    throw new InvalidOperationException("Falta Banco:ApiKey (mínimo 16 caracteres) en user-secrets del BancoSimulado.Api.");

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.UseSwaggerUI(o => o.SwaggerEndpoint("/openapi/v1.json", "Banco Simulado GT v1"));
}

// Autenticación por clave de API (comparación en tiempo constante)
app.Use(async (ctx, next) =>
{
    if (!ctx.Request.Path.StartsWithSegments("/api"))
    {
        await next();
        return;
    }
    var recibida = ctx.Request.Headers["X-Api-Key"].ToString();
    var ok = CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(recibida), Encoding.UTF8.GetBytes(apiKey));
    if (!ok)
    {
        ctx.Response.StatusCode = StatusCodes.Status401Unauthorized;
        await ctx.Response.WriteAsJsonAsync(new { codigo = "NO_AUTORIZADO", mensaje = "Clave de API inválida o ausente." });
        return;
    }
    await next();
});

app.MapGet("/health", (IConfiguration c) => Results.Ok(new { servicio = c["Banco:Nombre"], estado = "en línea", fechaUtc = DateTime.UtcNow }))
   .WithSummary("Estado del servicio bancario");

var api = app.MapGroup("/api/v1/transferencias").WithTags("Transferencias");

api.MapPost("/", async (SolicitudTransferencia s, HttpRequest req, AlmacenTransferencias almacen, IConfiguration config, ILogger<Program> log) =>
{
    // Validación de la solicitud
    var errores = new Dictionary<string, string[]>();
    if (s.OperacionId == Guid.Empty) errores["operacionId"] = ["Obligatorio."];
    if (s.Monto <= 0) errores["monto"] = ["Debe ser mayor que cero."];
    if (string.IsNullOrWhiteSpace(s.CuentaDestino)) errores["cuentaDestino"] = ["Obligatoria."];
    if (string.IsNullOrWhiteSpace(s.BancoDestino)) errores["bancoDestino"] = ["Obligatorio."];
    if (!string.Equals(s.Moneda, "GTQ", StringComparison.OrdinalIgnoreCase)) errores["moneda"] = ["Solo se acepta GTQ."];
    if (errores.Count > 0) return Results.ValidationProblem(errores, title: "Solicitud inválida");

    // Idempotencia: misma operación => misma respuesta, sin volver a debitar
    if (almacen.Obtener(s.OperacionId) is { } existente)
    {
        if (existente.Monto != s.Monto || existente.CuentaDestino != s.CuentaDestino)
            return Results.Conflict(new { codigo = "OPERACION_DUPLICADA", mensaje = "El operacionId ya se usó con otros datos." });
        return Results.Ok(existente.Respuesta);
    }

    var simular = req.Headers["X-Simular"].ToString().ToLowerInvariant();
    if (simular == "error")
        return Results.Problem(title: "Servicio no disponible", detail: "El banco no está disponible (simulado).", statusCode: 503);
    if (simular == "lento")
        await Task.Delay(TimeSpan.FromSeconds(15));
    else
        await Task.Delay(config.GetValue("Banco:RetrasoMilisegundos", 300));

    var limite = config.GetValue("Banco:LimitePorTransferencia", 50000m);
    var (estado, mensaje) = simular == "rechazo" ? ("RECHAZADA", "Rechazo simulado por el banco.")
        : s.Monto > limite ? ("RECHAZADA", $"El monto excede el límite por transferencia (Q{limite:N2}).")
        : s.CuentaDestino.Trim().EndsWith("0000") ? ("RECHAZADA", "La cuenta destino no existe.")
        : ("APROBADA", "Transferencia acreditada.");

    var respuesta = new RespuestaTransferencia(
        s.OperacionId, estado,
        estado == "APROBADA" ? $"SIM-{DateTime.UtcNow:yyyyMMdd}-{RandomNumberGenerator.GetInt32(100000, 999999)}" : null,
        mensaje, DateTime.UtcNow);

    almacen.Guardar(new Transferencia(s.OperacionId, s.Monto, s.CuentaDestino, s.BancoDestino, s.Concepto, respuesta));
    log.LogInformation("Transferencia {Operacion}: {Estado} Q{Monto}", s.OperacionId, estado, s.Monto);
    return Results.Ok(respuesta);
})
.WithSummary("Solicita una transferencia (idempotente por operacionId)");

api.MapGet("/{operacionId:guid}", (Guid operacionId, AlmacenTransferencias almacen) =>
    almacen.Obtener(operacionId) is { } t
        ? Results.Ok(t.Respuesta)
        : Results.NotFound(new { codigo = "NO_ENCONTRADA", mensaje = "No existe una transferencia con ese operacionId." }))
.WithSummary("Consulta el resultado de una transferencia");

api.MapGet("/", (AlmacenTransferencias almacen) => Results.Ok(almacen.Todas()))
   .WithSummary("Lista las transferencias recibidas (auditoría del banco)");

app.Run();

// ------------------------------- Modelos -------------------------------
public sealed record SolicitudTransferencia(Guid OperacionId, string BancoDestino, string CuentaDestino, decimal Monto, string Moneda, string? Concepto);
public sealed record RespuestaTransferencia(Guid OperacionId, string Estado, string? Autorizacion, string Mensaje, DateTime Fecha);
public sealed record Transferencia(Guid OperacionId, decimal Monto, string CuentaDestino, string BancoDestino, string? Concepto, RespuestaTransferencia Respuesta);

/// <summary>Guarda las transferencias en memoria y en un archivo JSON (persisten entre reinicios).</summary>
public sealed class AlmacenTransferencias
{
    private readonly ConcurrentDictionary<Guid, Transferencia> _datos = new();
    private readonly string _archivo;
    private readonly Lock _bloqueo = new();
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web) { WriteIndented = true };

    public AlmacenTransferencias(IConfiguration config, IWebHostEnvironment env)
    {
        _archivo = Path.Combine(env.ContentRootPath, config["Banco:ArchivoDatos"] ?? "datos/transferencias.json");
        Directory.CreateDirectory(Path.GetDirectoryName(_archivo)!);
        if (File.Exists(_archivo))
            foreach (var t in JsonSerializer.Deserialize<List<Transferencia>>(File.ReadAllText(_archivo), Json) ?? [])
                _datos[t.OperacionId] = t;
    }

    public Transferencia? Obtener(Guid id) => _datos.GetValueOrDefault(id);

    public IReadOnlyList<Transferencia> Todas() => _datos.Values.OrderByDescending(t => t.Respuesta.Fecha).ToList();

    public void Guardar(Transferencia t)
    {
        lock (_bloqueo)
        {
            if (!_datos.TryAdd(t.OperacionId, t)) return;
            File.WriteAllText(_archivo, JsonSerializer.Serialize(_datos.Values, Json));
        }
    }
}
