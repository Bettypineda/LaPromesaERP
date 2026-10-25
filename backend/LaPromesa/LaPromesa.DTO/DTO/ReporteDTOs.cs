using System.ComponentModel.DataAnnotations;

namespace LaPromesa.DTO.DTO
{
    /// <summary>Resultado de un reporte: encabezado/totales, resumen agrupado y detalle.</summary>
    public class ReporteDTO
    {
        public Dictionary<string, object?>? Totales { get; set; }
        public List<Dictionary<string, object?>> Resumen { get; set; } = new();
        public List<Dictionary<string, object?>> Detalle { get; set; } = new();
    }

    public class ReportePeriodoFiltroDTO : IValidatableObject
    {
        [Required(ErrorMessage = "La fecha inicial es obligatoria.")] public DateOnly? FechaDesde { get; set; }
        [Required(ErrorMessage = "La fecha final es obligatoria.")] public DateOnly? FechaHasta { get; set; }
        public int? IdProveedor { get; set; }
        public int? IdCategoria { get; set; }
        public int? IdBodega { get; set; }
        [RegularExpression("^(Pendiente|Aprobada|Parcial|Recibida|Anulada)$", ErrorMessage = "Valor no permitido.")] public string? Estado { get; set; }
        public bool IncluirAnuladas { get; set; }
        /// <summary>json (por defecto) o csv para descargar en Excel.</summary>
        public string? Formato { get; set; }

        public IEnumerable<ValidationResult> Validate(ValidationContext context)
        {
            if (FechaDesde > FechaHasta)
                yield return new ValidationResult("La fecha inicial no puede ser mayor que la final.", new[] { nameof(FechaDesde) });
        }
    }

    public class ReporteCuentasFiltroDTO
    {
        /// <summary>Si se omite, hoy.</summary>
        public DateOnly? FechaCorte { get; set; }
        public int? IdProveedor { get; set; }
        public int? IdCategoria { get; set; }
        public bool IncluirPagadas { get; set; }
        public string? Formato { get; set; }
    }
}
