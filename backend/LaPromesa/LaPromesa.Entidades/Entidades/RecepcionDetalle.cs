namespace LaPromesa.Entidades.Entidades
{
    /// <summary>Línea recibida en una recepción (compras.RecepcionesDetalle).</summary>
    public class RecepcionDetalle
    {
        public int IdRecepcionDetalle { get; set; }
        public int IdDetalleOrden { get; set; }
        public int IdProducto { get; set; }
        public string? CodigoProducto { get; set; }
        public string? Producto { get; set; }
        public string? UnidadMedida { get; set; }
        public decimal Cantidad { get; set; }
        public decimal CostoUnitario { get; set; }
        public decimal Subtotal { get; set; }
    }
}
