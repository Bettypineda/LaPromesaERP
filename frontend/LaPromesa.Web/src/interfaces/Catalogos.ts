// Catálogos temporales del módulo de Inventarios (inv.*), hasta integrar la API de Fernando
export interface Bodega {
  idBodega: number
  codigo: string
  nombre: string
  ubicacion: string | null
}

export interface Producto {
  idProducto: number
  codigo: string
  nombre: string
  unidadMedida: string
  costoPromedio: number
  stockMinimo: number
  existencia: number
}

export interface CategoriaConsulta {
  idCategoria: number
  nombre: string
  descripcion: string | null
  activo: boolean
  fechaCreacion: string
  creadoPor: string
}

export interface CategoriaAgregar {
  nombre: string
  descripcion: string
}
