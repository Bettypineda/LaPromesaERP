import api, { limpiarParametros } from './api'
import type { RespuestaApi } from '../interfaces/RespuestaApi'
import type { Reporte, ReporteCuentasFiltro, ReportePeriodoFiltro } from '../interfaces/Reporte'

export type TipoReporte = 'ReporteComprasPorProveedor' | 'ReporteCumplimientoProveedores' | 'ReporteCuentasPorPagar'

export const generarReporte = async (tipo: TipoReporte, filtro: ReportePeriodoFiltro | ReporteCuentasFiltro) => {
  const respuesta = await api.get<RespuestaApi<Reporte>>(`/api/Reportes/${tipo}`, { params: limpiarParametros(filtro) })
  return respuesta.data
}

// Descarga el CSV generado por el backend (se abre en Excel)
export const descargarReporteCsv = async (tipo: TipoReporte, filtro: ReportePeriodoFiltro | ReporteCuentasFiltro) => {
  const respuesta = await api.get<Blob>(`/api/Reportes/${tipo}`, {
    params: { ...limpiarParametros(filtro), formato: 'csv' },
    responseType: 'blob',
  })
  const disposicion = String(respuesta.headers['content-disposition'] ?? '')
  const coincide = /filename\*?=(?:UTF-8'')?"?([^";]+)"?/i.exec(disposicion)
  const nombre = coincide ? decodeURIComponent(coincide[1]) : `${tipo}.csv`
  const url = URL.createObjectURL(respuesta.data)
  const enlace = document.createElement('a')
  enlace.href = url
  enlace.download = nombre
  document.body.appendChild(enlace)
  enlace.click()
  enlace.remove()
  URL.revokeObjectURL(url)
}
