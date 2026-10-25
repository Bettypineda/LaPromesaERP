using LaPromesa.Datos.Datos;
using LaPromesa.DTO.DTO;
using LaPromesa.Entidades.Entidades;
using LaPromesa.Utilidades.Excepciones;

namespace LaPromesa.Negocio.Servicios
{
    /// <summary>Reglas de aplicación de Proveedores. Las reglas de datos se garantizan además en la BD.</summary>
    public class ProveedorNegocio
    {
        private readonly ProveedorDatos proveedorDatos;

        public ProveedorNegocio()
        {
            proveedorDatos = new ProveedorDatos();
        }

        // Método Consultar Proveedores
        public (List<Proveedor> lista, int total) ConsultarProveedores(ProveedorFiltroDTO f)
            => proveedorDatos.ConsultarProveedores(f.Buscar, f.Estado, f.TipoPago, f.IdCategoria,
                f.OrdenarPor, f.Direccion.ToUpperInvariant(), f.Pagina, f.TamanoPagina);

        // Método Buscar Proveedor
        public (Proveedor proveedor, List<OrdenCompra> ordenes, List<CuentaPorPagar> cuentas, Cumplimiento? cumplimiento)
            BuscarProveedor(int idProveedor)
        {
            var r = proveedorDatos.BuscarProveedor(idProveedor);
            if (r.proveedor is null) throw new ExcepcionNegocio("El proveedor no existe.", 404, 52001);
            return (r.proveedor, r.ordenes, r.cuentas, r.cumplimiento);
        }

        // Método Agregar Proveedor
        public Proveedor AgregarProveedor(Proveedor proveedor, string usuario)
            => proveedorDatos.AgregarProveedor(Normalizar(proveedor), usuario);

        // Método Editar Proveedor
        public Proveedor EditarProveedor(Proveedor proveedor, string usuario)
        {
            if (proveedor.RowVersion is null)
                throw new ExcepcionNegocio("Se requiere el rowVersion para editar.", 400, 51002);
            return proveedorDatos.EditarProveedor(Normalizar(proveedor), usuario);
        }

        // Método Eliminar Proveedor: eliminación lógica (inactivación con motivo)
        public Proveedor EliminarProveedor(int idProveedor, string? motivo, byte[]? rowVersion, string usuario)
        {
            if (string.IsNullOrWhiteSpace(motivo) || motivo.Trim().Length < 10)
                throw new ExcepcionNegocio("El motivo de inactivación es obligatorio (mínimo 10 caracteres).", 400, 51017);
            return proveedorDatos.InactivarProveedor(idProveedor, motivo.Trim(), rowVersion, usuario);
        }

        // Método Reactivar Proveedor
        public Proveedor ReactivarProveedor(int idProveedor, byte[]? rowVersion, string usuario)
            => proveedorDatos.ReactivarProveedor(idProveedor, rowVersion, usuario);

        // Métodos de Categorías
        public List<Categoria> ConsultarCategorias(bool soloActivas) => proveedorDatos.ConsultarCategorias(soloActivas);

        public Categoria AgregarCategoria(Categoria categoria, string usuario)
        {
            categoria.Nombre = categoria.Nombre.Trim();
            return proveedorDatos.AgregarCategoria(categoria, usuario);
        }

        private static Proveedor Normalizar(Proveedor p)
        {
            p.Nombre = p.Nombre.Trim();
            p.Nit = p.Nit.Trim().ToUpperInvariant();
            p.Email = string.IsNullOrWhiteSpace(p.Email) ? null : p.Email.Trim().ToLowerInvariant();
            return p;
        }
    }
}
