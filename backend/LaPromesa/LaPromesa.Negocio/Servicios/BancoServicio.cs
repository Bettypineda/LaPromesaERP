using System.Net;
using System.Net.Http.Json;
using LaPromesa.Utilidades.Configuracion;

namespace LaPromesa.Negocio.Servicios
{
    public enum ResultadoBanco { Aprobado, Rechazado, NoDisponible }

    public record RespuestaBanco(ResultadoBanco Resultado, string? Autorizacion, string Mensaje);

    /// <summary>
    /// Cliente de la API externa de pagos bancarios (BancoSimulado.API, servicio independiente).
    /// Se identifica con la clave X-Api-Key. El mismo OperacionId nunca genera dos débitos.
    /// </summary>
    public class BancoServicio
    {
        // HttpClient compartido (buena práctica: evita agotar sockets)
        private static readonly Lazy<HttpClient> Cliente = new(() =>
        {
            var http = new HttpClient
            {
                BaseAddress = new Uri(ConfiguracionBanco.UrlBase.TrimEnd('/') + "/"),
                Timeout = TimeSpan.FromSeconds(ConfiguracionBanco.TimeoutSegundos)
            };
            http.DefaultRequestHeaders.Add("X-Api-Key", ConfiguracionBanco.ApiKey);
            return http;
        });

        private record SolicitudTransferencia(Guid OperacionId, string BancoDestino, string CuentaDestino, decimal Monto, string Moneda, string Concepto);
        private record RespuestaTransferencia(Guid OperacionId, string Estado, string? Autorizacion, string? Mensaje, DateTime Fecha);

        public RespuestaBanco Transferir(Guid operacionId, string banco, string cuentaDestino, decimal monto, string concepto)
        {
            try
            {
                var solicitud = new SolicitudTransferencia(operacionId, banco, cuentaDestino, monto, "GTQ", concepto);
                using var respuesta = Cliente.Value.PostAsJsonAsync("api/v1/transferencias", solicitud).GetAwaiter().GetResult();

                if (respuesta.StatusCode is HttpStatusCode.OK or HttpStatusCode.Created)
                {
                    var r = respuesta.Content.ReadFromJsonAsync<RespuestaTransferencia>().GetAwaiter().GetResult();
                    if (r is null) return new(ResultadoBanco.NoDisponible, null, "Respuesta vacía del banco.");
                    return r.Estado.Equals("APROBADA", StringComparison.OrdinalIgnoreCase)
                        ? new(ResultadoBanco.Aprobado, r.Autorizacion, r.Mensaje ?? "Transferencia aprobada.")
                        : new(ResultadoBanco.Rechazado, null, r.Mensaje ?? "Transferencia rechazada por el banco.");
                }
                if (respuesta.StatusCode is HttpStatusCode.BadRequest or HttpStatusCode.UnprocessableEntity)
                    return new(ResultadoBanco.Rechazado, null, $"El banco rechazó la solicitud ({(int)respuesta.StatusCode}).");
                if (respuesta.StatusCode is HttpStatusCode.Unauthorized or HttpStatusCode.Forbidden)
                    return new(ResultadoBanco.NoDisponible, null, "Credenciales inválidas para la API bancaria.");
                return new(ResultadoBanco.NoDisponible, null, $"Banco no disponible ({(int)respuesta.StatusCode}).");
            }
            catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException)
            {
                return new(ResultadoBanco.NoDisponible, null, "Sin respuesta del banco (tiempo de espera agotado o servicio caído).");
            }
        }
    }
}
