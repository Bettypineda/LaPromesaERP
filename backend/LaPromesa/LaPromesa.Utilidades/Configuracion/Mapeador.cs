using System.Collections;
using System.Collections.Concurrent;
using System.Globalization;
using System.Reflection;

namespace LaPromesa.Utilidades.Configuracion
{
    /// <summary>
    /// Copia propiedades con el mismo nombre entre Entidades y DTO
    /// (equivalente sencillo a AutoMapper, sin dependencias externas).
    /// Soporta listas y objetos anidados.
    /// </summary>
    public static class Mapeador
    {
        private static readonly ConcurrentDictionary<Type, PropertyInfo[]> Cache = new();

        private static PropertyInfo[] Propiedades(Type tipo)
            => Cache.GetOrAdd(tipo, t => t.GetProperties(BindingFlags.Public | BindingFlags.Instance));

        public static TDestino Mapear<TDestino>(object origen) where TDestino : new()
            => (TDestino)MapearObjeto(origen, typeof(TDestino))!;

        public static List<TDestino> MapearLista<TDestino>(IEnumerable origen) where TDestino : new()
            => origen.Cast<object>().Select(Mapear<TDestino>).ToList();

        private static object? MapearObjeto(object? origen, Type tipoDestino)
        {
            if (origen is null) return null;
            var destino = Activator.CreateInstance(tipoDestino)!;
            var propsOrigen = Propiedades(origen.GetType()).ToDictionary(p => p.Name, StringComparer.OrdinalIgnoreCase);

            foreach (var pd in Propiedades(tipoDestino).Where(p => p.CanWrite))
            {
                if (!propsOrigen.TryGetValue(pd.Name, out var po) || !po.CanRead) continue;
                var valor = po.GetValue(origen);
                pd.SetValue(destino, Convertir(valor, pd.PropertyType));
            }
            return destino;
        }

        private static object? Convertir(object? valor, Type tipo)
        {
            if (valor is null) return null;
            if (tipo.IsInstanceOfType(valor)) return valor;

            // Listas de objetos: List<Entidad> -> List<Dto>
            if (tipo.IsGenericType && tipo.GetGenericTypeDefinition() == typeof(List<>) && valor is IEnumerable lista && valor is not string)
            {
                var tipoElemento = tipo.GetGenericArguments()[0];
                var resultado = (IList)Activator.CreateInstance(tipo)!;
                foreach (var item in lista)
                    resultado.Add(EsSimple(tipoElemento) ? Convertir(item, tipoElemento) : MapearObjeto(item, tipoElemento));
                return resultado;
            }

            var subyacente = Nullable.GetUnderlyingType(tipo) ?? tipo;
            if (subyacente.IsInstanceOfType(valor)) return valor;
            if (!EsSimple(subyacente)) return MapearObjeto(valor, subyacente);
            if (subyacente.IsEnum) return Enum.Parse(subyacente, valor.ToString()!, true);
            return System.Convert.ChangeType(valor, subyacente, CultureInfo.InvariantCulture);
        }

        private static bool EsSimple(Type t)
            => t.IsPrimitive || t.IsEnum || t == typeof(string) || t == typeof(decimal) || t == typeof(DateTime)
               || t == typeof(DateOnly) || t == typeof(TimeOnly) || t == typeof(Guid) || t == typeof(byte[])
               || Nullable.GetUnderlyingType(t) is not null;
    }
}
