// Respuesta estándar de todas las APIs del backend (formato del curso)
export interface RespuestaApi<T> {
  exito: boolean
  mensaje: string
  datos: T
  detalle: string | null
}

// Listados con paginación (ResultadoPaginadoDTO del backend)
export interface ResultadoPaginado<T> {
  registros: T[]
  total: number
  pagina: number
  tamanoPagina: number
  totalPaginas: number
}
