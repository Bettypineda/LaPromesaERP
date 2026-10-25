using System.Collections.Concurrent;
using System.Data;
using System.Globalization;
using System.Reflection;
using LaPromesa.Utilidades.Configuracion;
using LaPromesa.Utilidades.Excepciones;
using Microsoft.Data.SqlClient;

namespace LaPromesa.Datos.Conexion
{
    /// <summary>
    /// Utilidades comunes de la capa Datos (ADO.NET):
    ///   - Abrir conexión y crear comandos de procedimientos almacenados.
    ///   - Agregar parámetros (null → DBNull, DateOnly → DATE).
    ///   - Convertir los errores de negocio de SQL Server (51xxx-54xxx) en ExcepcionNegocio.
    ///   - Leer filas del SqlDataReader hacia Entidades por nombre de columna.
    /// </summary>
    public static class AccesoDatos
    {
        private static readonly ConcurrentDictionary<Type, Dictionary<string, PropertyInfo>> Cache = new();

        public static SqlConnection CrearConexion() => new SqlConnection(ConexionSQL.CadenaConexion);

        public static SqlCommand CrearProcedimiento(SqlConnection conexion, string procedimiento)
            => new SqlCommand(procedimiento, conexion) { CommandType = CommandType.StoredProcedure, CommandTimeout = 30 };

        /// <summary>Agrega un parámetro; null se envía como NULL.</summary>
        public static void Parametro(this SqlCommand comando, string nombre, object? valor)
        {
            object final = valor switch
            {
                null => DBNull.Value,
                DateOnly fecha => fecha.ToDateTime(TimeOnly.MinValue),
                string texto when string.IsNullOrWhiteSpace(texto) => DBNull.Value,
                _ => valor
            };
            var p = comando.Parameters.AddWithValue(nombre, final);
            if (valor is DateOnly) p.SqlDbType = SqlDbType.Date;
            // ROWVERSION viaja como BINARY(8); si llega null, SQL Server no puede inferir el tipo desde DBNull
            if (valor is byte[] || nombre.EndsWith("RowVersion", StringComparison.OrdinalIgnoreCase))
            {
                p.SqlDbType = SqlDbType.Binary;
                p.Size = 8;
            }
        }

        /// <summary>Ejecuta la operación y traduce los errores de negocio de la base de datos.</summary>
        public static T Ejecutar<T>(Func<T> operacion)
        {
            try
            {
                return operacion();
            }
            catch (SqlException ex) when (ex.Number >= 51000 && ex.Number < 55000)
            {
                throw new ExcepcionNegocio(ex.Message, ExcepcionNegocio.EstadoDesdeCodigo(ex.Number), ex.Number);
            }
        }

        /// <summary>Lee todas las filas del resultado actual como lista de entidades.</summary>
        public static List<T> LeerLista<T>(SqlDataReader lector) where T : new()
        {
            var lista = new List<T>();
            while (lector.Read()) lista.Add(LeerFila<T>(lector));
            return lista;
        }

        /// <summary>Convierte la fila actual en una entidad (columna = propiedad, sin importar mayúsculas).</summary>
        public static T LeerFila<T>(SqlDataReader lector) where T : new()
        {
            var props = Cache.GetOrAdd(typeof(T), t => t.GetProperties(BindingFlags.Public | BindingFlags.Instance)
                .Where(p => p.CanWrite).ToDictionary(p => p.Name, StringComparer.OrdinalIgnoreCase));
            var entidad = new T();
            for (var i = 0; i < lector.FieldCount; i++)
            {
                if (!props.TryGetValue(lector.GetName(i), out var prop) || lector.IsDBNull(i)) continue;
                prop.SetValue(entidad, Convertir(lector.GetValue(i), prop.PropertyType));
            }
            return entidad;
        }

        /// <summary>Lee el resultado actual como filas genéricas (para reportes); claves en camelCase.</summary>
        public static List<Dictionary<string, object?>> LeerFilas(SqlDataReader lector)
        {
            var filas = new List<Dictionary<string, object?>>();
            while (lector.Read())
            {
                var fila = new Dictionary<string, object?>();
                for (var i = 0; i < lector.FieldCount; i++)
                {
                    var nombre = lector.GetName(i);
                    var clave = char.ToLowerInvariant(nombre[0]) + nombre[1..];
                    var valor = lector.IsDBNull(i) ? null : lector.GetValue(i);
                    if (valor is DateTime d && lector.GetDataTypeName(i).Equals("date", StringComparison.OrdinalIgnoreCase))
                        valor = DateOnly.FromDateTime(d);
                    fila[clave] = valor;
                }
                filas.Add(fila);
            }
            return filas;
        }

        /// <summary>Total de registros de un listado paginado (columna TotalRegistros).</summary>
        public static int LeerListaPaginada<T>(SqlDataReader lector, List<T> destino) where T : new()
        {
            var total = 0;
            int? ordinal = null;
            while (lector.Read())
            {
                ordinal ??= TryOrdinal(lector, "TotalRegistros");
                if (ordinal is int o && !lector.IsDBNull(o)) total = lector.GetInt32(o);
                destino.Add(LeerFila<T>(lector));
            }
            return total;
        }

        private static int? TryOrdinal(SqlDataReader lector, string columna)
        {
            for (var i = 0; i < lector.FieldCount; i++)
                if (lector.GetName(i).Equals(columna, StringComparison.OrdinalIgnoreCase)) return i;
            return null;
        }

        private static object? Convertir(object valor, Type tipo)
        {
            var t = Nullable.GetUnderlyingType(tipo) ?? tipo;
            if (t.IsInstanceOfType(valor)) return valor;
            if (t == typeof(DateOnly)) return DateOnly.FromDateTime(Convert.ToDateTime(valor));
            if (t == typeof(TimeOnly)) return valor is TimeSpan ts ? TimeOnly.FromTimeSpan(ts) : TimeOnly.FromDateTime(Convert.ToDateTime(valor));
            if (t == typeof(Guid)) return Guid.Parse(valor.ToString()!);
            return Convert.ChangeType(valor, t, CultureInfo.InvariantCulture);
        }
    }
}
