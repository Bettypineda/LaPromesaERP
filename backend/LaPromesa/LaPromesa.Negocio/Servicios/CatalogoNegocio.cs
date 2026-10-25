using LaPromesa.Datos.Datos;
using LaPromesa.Entidades.Entidades;

namespace LaPromesa.Negocio.Servicios
{
    /// <summary>Catálogos para los formularios (bodegas y productos activos).</summary>
    public class CatalogoNegocio
    {
        private readonly CatalogoDatos catalogoDatos;

        public CatalogoNegocio()
        {
            catalogoDatos = new CatalogoDatos();
        }

        public List<Bodega> ConsultarBodegas() => catalogoDatos.ConsultarBodegas();

        public List<Producto> ConsultarProductos(string? buscar) => catalogoDatos.ConsultarProductos(buscar);
    }
}
