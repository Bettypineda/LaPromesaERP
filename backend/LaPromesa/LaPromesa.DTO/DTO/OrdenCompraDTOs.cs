using System.ComponentModel.DataAnnotations;

namespace LaPromesa.DTO.DTO
{
    /// <summary>Filtros de ConsultarOrdenesCompra.</summary>
    public class OrdenCompraFiltroDTO
    {
        /// <summary>Número de orden o nombre/NIT del proveedor.</summary>
        [StringLength(100, ErrorMessage = "Máximo {1} caracteres.")] public string? Buscar { get; set; }
        [RegularExpression("^(Pendiente|Aprobada|Parcial|Recibida|Anulada)$", ErrorMessage = "Valor no permitido.")] public string? Estado { get; set; }
        public int? IdProveedor { get; set; }
        public int? IdBodega { get; set; }
        public DateOnly? FechaDesde { get; set; }
        public DateOnly? FechaHasta { get; set; }
        public bool SoloAtrasadas { get; set; }
        /// <summary>Numero, Proveedor, FechaOrden, FechaEsperada, Total, Estado</summary>
        public string OrdenarPor { get; set; } = "FechaOrden";
        [RegularExpression("^(ASC|DESC|asc|desc)$", ErrorMessage = "Valor no permitido.")] public string Direccion { get; set; } = "DESC";
        [Range(1, int.MaxValue, ErrorMessage = "Valor fuera del rango permitido.")] public int Pagina { get; set; } = 1;
        [Range(1, 100, ErrorMessage = "Valor fuera del rango permitido.")] public int TamanoPagina { get; set; } = 10;
    }

    public class LineaOrdenAgregarDTO
    {
        [Range(1, int.MaxValue, ErrorMessage = "Seleccione un producto.")] public int IdProducto { get; set; }
        [Range(0.01, 9999999, ErrorMessage = "La cantidad debe ser mayor que cero.")] public decimal CantidadPedida { get; set; }
        [Range(0.0001, 9999999, ErrorMessage = "El costo unitario debe ser mayor que cero.")] public decimal CostoUnitario { get; set; }
    }

    /// <summary>Datos para crear una orden de compra (queda Pendiente; el total lo calcula la BD).</summary>
    public class OrdenCompraAgregarDTO : IValidatableObject
    {
        [Range(1, int.MaxValue, ErrorMessage = "Seleccione un proveedor.")] public int IdProveedor { get; set; }
        [Range(1, int.MaxValue, ErrorMessage = "Seleccione una bodega.")] public int IdBodega { get; set; }
        /// <summary>Si se omite, la fecha de hoy.</summary>
        public DateOnly? FechaOrden { get; set; }
        [Required(ErrorMessage = "La fecha esperada de entrega es obligatoria.")] public DateOnly? FechaEsperada { get; set; }
        [StringLength(300, ErrorMessage = "Máximo {1} caracteres.")] public string? Observaciones { get; set; }
        [Required(ErrorMessage = "Dato obligatorio."), MinLength(1, ErrorMessage = "La orden debe tener al menos una línea."), MaxLength(100)]
        public List<LineaOrdenAgregarDTO> Lineas { get; set; } = new();

        public IEnumerable<ValidationResult> Validate(ValidationContext context)
        {
            var hoy = DateOnly.FromDateTime(DateTime.Today);
            var fechaOrden = FechaOrden ?? hoy;
            if (fechaOrden > hoy)
                yield return new ValidationResult("La fecha de la orden no puede ser futura.", new[] { nameof(FechaOrden) });
            if (FechaEsperada is { } esperada && esperada < fechaOrden)
                yield return new ValidationResult("La fecha esperada debe ser igual o posterior a la fecha de la orden.", new[] { nameof(FechaEsperada) });
            if (Lineas.GroupBy(l => l.IdProducto).Any(g => g.Count() > 1))
                yield return new ValidationResult("Un producto no puede repetirse en la misma orden.", new[] { nameof(Lineas) });
        }
    }

    /// <summary>Datos para editar una orden (solo en estado Pendiente).</summary>
    public class OrdenCompraEditarDTO : OrdenCompraAgregarDTO
    {
        [Range(1, int.MaxValue, ErrorMessage = "El código de la orden es obligatorio.")] public int IdOrdenCompra { get; set; }
        [Required(ErrorMessage = "El rowVersion es obligatorio.")] public byte[]? RowVersion { get; set; }
    }

    /// <summary>Aprobar una orden.</summary>
    public class OrdenCompraAprobarDTO
    {
        [Range(1, int.MaxValue, ErrorMessage = "Valor fuera del rango permitido.")] public int IdOrdenCompra { get; set; }
        public byte[]? RowVersion { get; set; }
    }

    /// <summary>Detalle completo de la orden (BuscarOrdenCompra).</summary>
    public class OrdenCompraDetalleDTO
    {
        public OrdenCompraConsultaDTO Orden { get; set; } = new();
        public List<OrdenCompraLineaDTO> Lineas { get; set; } = new();
        public List<RecepcionConsultaDTO> Recepciones { get; set; } = new();
        public List<HistorialOrdenDTO> Historial { get; set; } = new();
    }

    // ------------------------------ RECEPCIONES ------------------------------

    public class LineaRecepcionAgregarDTO
    {
        [Range(1, int.MaxValue, ErrorMessage = "Valor fuera del rango permitido.")] public int IdDetalle { get; set; }
        [Range(0.01, 9999999, ErrorMessage = "La cantidad recibida debe ser mayor que cero.")] public decimal Cantidad { get; set; }
    }

    /// <summary>Recepción de mercadería (parcial o total) de una orden aprobada.</summary>
    public class RecepcionAgregarDTO : IValidatableObject
    {
        [Range(1, int.MaxValue, ErrorMessage = "Indique la orden de compra.")] public int IdOrdenCompra { get; set; }
        /// <summary>Si se omite, hoy.</summary>
        public DateOnly? FechaRecepcion { get; set; }
        [StringLength(20, ErrorMessage = "Máximo {1} caracteres.")] public string? SerieFactura { get; set; }
        [Required(ErrorMessage = "El número de factura es obligatorio."), StringLength(30, ErrorMessage = "Máximo {1} caracteres.")] public string NumeroFactura { get; set; } = string.Empty;
        [StringLength(300, ErrorMessage = "Máximo {1} caracteres.")] public string? Observaciones { get; set; }
        [Required(ErrorMessage = "Dato obligatorio."), MinLength(1, ErrorMessage = "Indique al menos una línea recibida.")] public List<LineaRecepcionAgregarDTO> Lineas { get; set; } = new();

        public IEnumerable<ValidationResult> Validate(ValidationContext context)
        {
            if (FechaRecepcion is { } f && f > DateOnly.FromDateTime(DateTime.Today))
                yield return new ValidationResult("La fecha de recepción no puede ser futura.", new[] { nameof(FechaRecepcion) });
            if (Lineas.GroupBy(l => l.IdDetalle).Any(g => g.Count() > 1))
                yield return new ValidationResult("Una línea no puede repetirse en la misma recepción.", new[] { nameof(Lineas) });
        }
    }

    public class RecepcionFiltroDTO
    {
        public int? IdOrdenCompra { get; set; }
        public int? IdProveedor { get; set; }
        [RegularExpression("^(ATiempo|Retraso|Anticipada)$", ErrorMessage = "Valor no permitido.")] public string? Cumplimiento { get; set; }
        public DateOnly? FechaDesde { get; set; }
        public DateOnly? FechaHasta { get; set; }
        [Range(1, int.MaxValue, ErrorMessage = "Valor fuera del rango permitido.")] public int Pagina { get; set; } = 1;
        [Range(1, 100, ErrorMessage = "Valor fuera del rango permitido.")] public int TamanoPagina { get; set; } = 10;
    }

    /// <summary>Nota de compra con sus líneas (BuscarRecepcion).</summary>
    public class RecepcionDetalleDTO
    {
        public RecepcionConsultaDTO Recepcion { get; set; } = new();
        public List<RecepcionLineaDTO> Lineas { get; set; } = new();
    }
}
