using System.ComponentModel.DataAnnotations;

namespace LaPromesa.DTO.DTO
{
    public class CuentaPorPagarFiltroDTO
    {
        public int? IdProveedor { get; set; }
        [RegularExpression("^(Pendiente|Parcial|Pagada)$", ErrorMessage = "Valor no permitido.")] public string? Estado { get; set; }
        public bool SoloVencidas { get; set; }
        public bool SoloConSaldo { get; set; } = true;
        public DateOnly? VenceDesde { get; set; }
        public DateOnly? VenceHasta { get; set; }
        [Range(1, int.MaxValue, ErrorMessage = "Valor fuera del rango permitido.")] public int Pagina { get; set; } = 1;
        [Range(1, 100, ErrorMessage = "Valor fuera del rango permitido.")] public int TamanoPagina { get; set; } = 10;
    }

    /// <summary>Detalle de una cuenta por pagar y sus pagos.</summary>
    public class CuentaPorPagarDetalleDTO
    {
        public CuentaPorPagarConsultaDTO Cuenta { get; set; } = new();
        public List<PagoConsultaDTO> Pagos { get; set; } = new();
    }

    /// <summary>
    /// Registrar un pago. Transferencia: se envía a la API bancaria externa.
    /// OperacionId lo genera el frontend una vez por intento: repetir la petición no duplica el pago.
    /// </summary>
    public class PagoAgregarDTO : IValidatableObject
    {
        [Range(1, int.MaxValue, ErrorMessage = "Indique la cuenta por pagar.")] public int IdCuentaPagar { get; set; }
        [Required(ErrorMessage = "El operacionId es obligatorio.")] public Guid? OperacionId { get; set; }
        [Range(0.01, 99999999, ErrorMessage = "El monto debe ser mayor que cero.")] public decimal Monto { get; set; }
        [Required(ErrorMessage = "Dato obligatorio."), RegularExpression("^(Transferencia|Cheque|Efectivo)$", ErrorMessage = "Método: Transferencia, Cheque o Efectivo.")]
        public string Metodo { get; set; } = "Transferencia";
        /// <summary>Transferencia: si se omite, el banco registrado del proveedor.</summary>
        [StringLength(60, ErrorMessage = "Máximo {1} caracteres.")] public string? Banco { get; set; }
        [StringLength(30, ErrorMessage = "Máximo {1} caracteres.")] public string? CuentaDestino { get; set; }
        /// <summary>Cheque: número de cheque (obligatorio).</summary>
        [StringLength(50, ErrorMessage = "Máximo {1} caracteres.")] public string? Referencia { get; set; }

        public IEnumerable<ValidationResult> Validate(ValidationContext context)
        {
            if (Metodo == "Cheque" && string.IsNullOrWhiteSpace(Referencia))
                yield return new ValidationResult("Para pagos con cheque indique el número de cheque.", new[] { nameof(Referencia) });
            if (OperacionId == Guid.Empty)
                yield return new ValidationResult("El operacionId no puede ser vacío.", new[] { nameof(OperacionId) });
        }
    }
}
