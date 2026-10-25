namespace LaPromesa.Entidades.Entidades
{
    /// <summary>Nota de compra / recepción de mercadería (vista compras.vw_Recepciones).</summary>
    public class Recepcion
    {
        public int IdRecepcion { get; set; }
        public string Numero { get; set; } = string.Empty;
        public int IdOrdenCompra { get; set; }
        public string NumeroOrden { get; set; } = string.Empty;
        public int IdProveedor { get; set; }
        public string Proveedor { get; set; } = string.Empty;
        public string NitProveedor { get; set; } = string.Empty;
        public int IdBodega { get; set; }
        public string Bodega { get; set; } = string.Empty;
        public DateOnly FechaRecepcion { get; set; }
        public DateOnly FechaEsperada { get; set; }
        public string Cumplimiento { get; set; } = string.Empty;
        public int DiasDiferencia { get; set; }
        public string? SerieFactura { get; set; }
        public string NumeroFactura { get; set; } = string.Empty;
        public string Factura { get; set; } = string.Empty;
        public decimal Subtotal { get; set; }
        public decimal Iva { get; set; }
        public decimal Total { get; set; }
        public string? Observaciones { get; set; }
        public DateTime FechaCreacion { get; set; }
        public string RecibidoPor { get; set; } = string.Empty;
        public int? IdCuentaPagar { get; set; }
        public string? NumeroCuentaPagar { get; set; }
        public List<RecepcionDetalle> Detalle { get; set; } = new();
    }
}
