namespace LaPromesa.DTO.DTO
{
    /// <summary>Respuesta: Proveedor (compras.Proveedores / vista compras.vw_Proveedores). RQ25.</summary>
    public class ProveedorConsultaDTO
    {
        public int IdProveedor { get; set; }
        public string Codigo { get; set; } = string.Empty;
        public string Nombre { get; set; } = string.Empty;
        public string Nit { get; set; } = string.Empty;
        public int IdCategoria { get; set; }
        public string Categoria { get; set; } = string.Empty;
        public string? Contacto { get; set; }
        public string? Telefono { get; set; }
        public string? Email { get; set; }
        public string? Direccion { get; set; }
        public string? Departamento { get; set; }
        public string TipoPago { get; set; } = string.Empty;
        public int DiasCredito { get; set; }
        public decimal LimiteCredito { get; set; }
        public string? Banco { get; set; }
        public string? NumeroCuenta { get; set; }
        public string Estado { get; set; } = string.Empty;
        public DateTime FechaCreacion { get; set; }
        public string CreadoPor { get; set; } = string.Empty;
        public DateTime? FechaModificacion { get; set; }
        public string? ModificadoPor { get; set; }
        public DateTime? FechaInactivacion { get; set; }
        public string? InactivadoPor { get; set; }
        public string? MotivoInactivacion { get; set; }
        /// <summary>Versión del registro (Base64). Se envía de vuelta al editar para evitar sobrescribir cambios de otro usuario.</summary>
        public byte[]? RowVersion { get; set; }
        public int OrdenesAbiertas { get; set; }
        public decimal SaldoPendiente { get; set; }
        public decimal? CreditoDisponible { get; set; }
        public DateOnly? UltimaCompra { get; set; }
    }
}
