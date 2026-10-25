namespace LaPromesa.DTO.DTO
{
    /// <summary>Respuesta: Encabezado de orden de compra (compras.OrdenesCompra / vista compras.vw_OrdenesCompra). RQ04, RQ27.</summary>
    public class OrdenCompraConsultaDTO
    {
        public int IdOrdenCompra { get; set; }
        public string Numero { get; set; } = string.Empty;
        public int IdProveedor { get; set; }
        public string CodigoProveedor { get; set; } = string.Empty;
        public string Proveedor { get; set; } = string.Empty;
        public string NitProveedor { get; set; } = string.Empty;
        public int IdBodega { get; set; }
        public string Bodega { get; set; } = string.Empty;
        public DateOnly FechaOrden { get; set; }
        public DateOnly FechaEsperada { get; set; }
        public string TipoPago { get; set; } = string.Empty;
        public int DiasCredito { get; set; }
        public string? Observaciones { get; set; }
        public decimal Subtotal { get; set; }
        public decimal TasaIva { get; set; }
        public decimal Iva { get; set; }
        public decimal Total { get; set; }
        public string Estado { get; set; } = string.Empty;
        public DateTime FechaCreacion { get; set; }
        public string CreadoPor { get; set; } = string.Empty;
        public DateTime? FechaModificacion { get; set; }
        public string? ModificadoPor { get; set; }
        public DateTime? FechaAprobacion { get; set; }
        public string? AprobadoPor { get; set; }
        public DateTime? FechaAnulacion { get; set; }
        public string? AnuladoPor { get; set; }
        public string? MotivoAnulacion { get; set; }
        /// <summary>Versión del registro (Base64). Se envía de vuelta al editar para evitar sobrescribir cambios de otro usuario.</summary>
        public byte[]? RowVersion { get; set; }
        public int Lineas { get; set; }
        public decimal CantidadPedida { get; set; }
        public decimal CantidadRecibida { get; set; }
        public decimal PorcentajeRecibido { get; set; }
        public int Recepciones { get; set; }
        public decimal TotalRecibido { get; set; }
        public int DiasParaEntrega { get; set; }
        public bool EstaAtrasada { get; set; }
        public List<OrdenCompraLineaDTO> Detalle { get; set; } = new();
    }
}
