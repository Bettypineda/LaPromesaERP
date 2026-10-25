namespace LaPromesa.DTO.DTO
{
    /// <summary>Respuesta: Cuenta por pagar generada por una recepción (vista compras.vw_CuentasPorPagar).</summary>
    public class CuentaPorPagarConsultaDTO
    {
        public int IdCuentaPagar { get; set; }
        public string Numero { get; set; } = string.Empty;
        public int IdRecepcion { get; set; }
        public string NumeroRecepcion { get; set; } = string.Empty;
        public int IdOrdenCompra { get; set; }
        public string NumeroOrden { get; set; } = string.Empty;
        public string FacturaProveedor { get; set; } = string.Empty;
        public int IdProveedor { get; set; }
        public string CodigoProveedor { get; set; } = string.Empty;
        public string Proveedor { get; set; } = string.Empty;
        public string NitProveedor { get; set; } = string.Empty;
        public string? Banco { get; set; }
        public string? NumeroCuenta { get; set; }
        public DateOnly FechaEmision { get; set; }
        public DateOnly FechaVencimiento { get; set; }
        public decimal Monto { get; set; }
        public decimal Saldo { get; set; }
        public string Estado { get; set; } = string.Empty;
        public decimal MontoEnProceso { get; set; }
        public decimal SaldoDisponible { get; set; }
        public int DiasVencida { get; set; }
        public string RangoAntiguedad { get; set; } = string.Empty;
        public DateTime FechaCreacion { get; set; }
        public DateTime? FechaModificacion { get; set; }
        /// <summary>Versión del registro (Base64). Se envía de vuelta al editar para evitar sobrescribir cambios de otro usuario.</summary>
        public byte[]? RowVersion { get; set; }
    }
}
