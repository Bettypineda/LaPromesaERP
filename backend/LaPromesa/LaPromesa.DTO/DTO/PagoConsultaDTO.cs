namespace LaPromesa.DTO.DTO
{
    /// <summary>Respuesta: Pago a proveedor (vista compras.vw_PagosProveedor).</summary>
    public class PagoConsultaDTO
    {
        public int IdPago { get; set; }
        public string Numero { get; set; } = string.Empty;
        public Guid OperacionId { get; set; }
        public int IdCuentaPagar { get; set; }
        public string NumeroCuentaPagar { get; set; } = string.Empty;
        public int IdProveedor { get; set; }
        public string Proveedor { get; set; } = string.Empty;
        public decimal Monto { get; set; }
        public string Metodo { get; set; } = string.Empty;
        public string? Banco { get; set; }
        public string? CuentaDestino { get; set; }
        public string? ReferenciaBanco { get; set; }
        public string Estado { get; set; } = string.Empty;
        public string? MensajeBanco { get; set; }
        public int Intentos { get; set; }
        public DateTime FechaSolicitud { get; set; }
        public DateTime? FechaConfirmacion { get; set; }
        public string RegistradoPor { get; set; } = string.Empty;
        public string? ConfirmadoPor { get; set; }
    }
}
