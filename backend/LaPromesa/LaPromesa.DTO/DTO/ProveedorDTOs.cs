using System.ComponentModel.DataAnnotations;

namespace LaPromesa.DTO.DTO
{
    /// <summary>Filtros de ConsultarProveedores.</summary>
    public class ProveedorFiltroDTO
    {
        /// <summary>Busca por nombre, NIT, contacto o código.</summary>
        [StringLength(100, ErrorMessage = "Máximo {1} caracteres.")] public string? Buscar { get; set; }
        [RegularExpression("^(Activo|Inactivo)$", ErrorMessage = "Estado debe ser Activo o Inactivo.")] public string? Estado { get; set; }
        [RegularExpression("^(Contado|Credito)$", ErrorMessage = "TipoPago debe ser Contado o Credito.")] public string? TipoPago { get; set; }
        public int? IdCategoria { get; set; }
        /// <summary>Codigo, Nombre, Nit, Categoria, TipoPago, DiasCredito, Estado, FechaCreacion, SaldoPendiente</summary>
        public string OrdenarPor { get; set; } = "Nombre";
        [RegularExpression("^(ASC|DESC|asc|desc)$", ErrorMessage = "Valor no permitido.")] public string Direccion { get; set; } = "ASC";
        [Range(1, int.MaxValue, ErrorMessage = "Valor fuera del rango permitido.")] public int Pagina { get; set; } = 1;
        [Range(1, 100, ErrorMessage = "Valor fuera del rango permitido.")] public int TamanoPagina { get; set; } = 10;
    }

    /// <summary>Datos para registrar un proveedor.</summary>
    public class ProveedorAgregarDTO : IValidatableObject
    {
        [Required(ErrorMessage = "El nombre es obligatorio."), StringLength(150, MinimumLength = 3, ErrorMessage = "Debe tener entre {2} y {1} caracteres.")]
        public string Nombre { get; set; } = string.Empty;

        [Required(ErrorMessage = "El NIT es obligatorio."), StringLength(15, ErrorMessage = "Máximo {1} caracteres."), NitGuatemala]
        public string Nit { get; set; } = string.Empty;

        [Range(1, int.MaxValue, ErrorMessage = "Seleccione una categoría.")]
        public int IdCategoria { get; set; }

        [StringLength(100, ErrorMessage = "Máximo {1} caracteres.")] public string? Contacto { get; set; }
        [StringLength(20, ErrorMessage = "Máximo {1} caracteres."), TelefonoGuatemala] public string? Telefono { get; set; }
        [StringLength(150, ErrorMessage = "Máximo {1} caracteres."), EmailAddress(ErrorMessage = "Correo inválido.")] public string? Email { get; set; }
        [StringLength(200, ErrorMessage = "Máximo {1} caracteres.")] public string? Direccion { get; set; }
        [StringLength(50, ErrorMessage = "Máximo {1} caracteres.")] public string? Departamento { get; set; }

        [Required(ErrorMessage = "Dato obligatorio."), RegularExpression("^(Contado|Credito)$", ErrorMessage = "El tipo de pago debe ser Contado o Credito.")]
        public string TipoPago { get; set; } = "Contado";

        [Range(0, 180, ErrorMessage = "Los días de crédito deben estar entre 0 y 180.")]
        public int DiasCredito { get; set; }

        [Range(0, 99999999, ErrorMessage = "El límite de crédito no puede ser negativo.")]
        public decimal LimiteCredito { get; set; }

        [StringLength(60, ErrorMessage = "Máximo {1} caracteres.")] public string? Banco { get; set; }
        [StringLength(30, ErrorMessage = "Máximo {1} caracteres.")] public string? NumeroCuenta { get; set; }

        public IEnumerable<ValidationResult> Validate(ValidationContext context)
        {
            if (TipoPago == "Contado" && DiasCredito != 0)
                yield return new ValidationResult("Un proveedor de contado debe tener 0 días de crédito.", new[] { nameof(DiasCredito) });
            if (TipoPago == "Credito" && DiasCredito < 1)
                yield return new ValidationResult("Un proveedor al crédito debe tener al menos 1 día de crédito.", new[] { nameof(DiasCredito) });
            if (TipoPago == "Contado" && LimiteCredito != 0)
                yield return new ValidationResult("Un proveedor de contado no tiene límite de crédito.", new[] { nameof(LimiteCredito) });
            if (string.IsNullOrWhiteSpace(Banco) != string.IsNullOrWhiteSpace(NumeroCuenta))
                yield return new ValidationResult("Si registra datos bancarios, indique banco y número de cuenta.", new[] { nameof(Banco), nameof(NumeroCuenta) });
        }
    }

    /// <summary>Datos para editar un proveedor (requiere RowVersion).</summary>
    public class ProveedorEditarDTO : ProveedorAgregarDTO
    {
        [Range(1, int.MaxValue, ErrorMessage = "El código del proveedor es obligatorio.")]
        public int IdProveedor { get; set; }

        [Required(ErrorMessage = "El rowVersion es obligatorio.")]
        public byte[]? RowVersion { get; set; }
    }

    /// <summary>Detalle completo del proveedor (BuscarProveedor).</summary>
    public class ProveedorDetalleDTO
    {
        public ProveedorConsultaDTO Proveedor { get; set; } = new();
        public List<OrdenCompraConsultaDTO> UltimasOrdenes { get; set; } = new();
        public List<CuentaPorPagarConsultaDTO> CuentasPorPagar { get; set; } = new();
        public CumplimientoDTO? Cumplimiento { get; set; }
    }

    public class CategoriaAgregarDTO
    {
        [Required(ErrorMessage = "El nombre es obligatorio."), StringLength(50, MinimumLength = 3, ErrorMessage = "Debe tener entre {2} y {1} caracteres.")]
        public string Nombre { get; set; } = string.Empty;
        [StringLength(200, ErrorMessage = "Máximo {1} caracteres.")] public string? Descripcion { get; set; }
    }
}
