export type FilaReporte = Record<string, string | number | boolean | null>

export interface Reporte {
  totales: FilaReporte | null
  resumen: FilaReporte[]
  detalle: FilaReporte[]
}

export interface ReportePeriodoFiltro {
  fechaDesde: string
  fechaHasta: string
  idProveedor?: number
  idCategoria?: number
  idBodega?: number
  estado?: string
  incluirAnuladas?: boolean
}

export interface ReporteCuentasFiltro {
  fechaCorte: string
  idProveedor?: number
  idCategoria?: number
  incluirPagadas?: boolean
}
