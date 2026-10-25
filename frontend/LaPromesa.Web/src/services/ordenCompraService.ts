import api, { limpiarParametros } from './api'
import type { RespuestaApi, ResultadoPaginado } from '../interfaces/RespuestaApi'
import type {
  OrdenCompraAgregar, OrdenCompraConsulta, OrdenCompraDetalle, OrdenCompraEditar, OrdenCompraFiltro,
} from '../interfaces/OrdenCompra'
import type { RecepcionAgregar, RecepcionConsulta } from '../interfaces/Recepcion'

export const consultarOrdenesCompra = async (filtro: Partial<OrdenCompraFiltro>) => {
  const respuesta = await api.get<RespuestaApi<ResultadoPaginado<OrdenCompraConsulta>>>(
    '/api/OrdenesCompra/ConsultarOrdenesCompra', { params: limpiarParametros(filtro) })
  return respuesta.data
}

export const buscarOrdenCompra = async (codigoOrdenCompra: number) => {
  const respuesta = await api.get<RespuestaApi<OrdenCompraDetalle>>(`/api/OrdenesCompra/BuscarOrdenCompra/${codigoOrdenCompra}`)
  return respuesta.data
}

export const agregarOrdenCompra = async (orden: OrdenCompraAgregar) => {
  const respuesta = await api.post<RespuestaApi<OrdenCompraConsulta>>('/api/OrdenesCompra/AgregarOrdenCompra', orden)
  return respuesta.data
}

export const editarOrdenCompra = async (orden: OrdenCompraEditar) => {
  const respuesta = await api.put<RespuestaApi<OrdenCompraConsulta>>('/api/OrdenesCompra/EditarOrdenCompra', orden)
  return respuesta.data
}

export const aprobarOrdenCompra = async (idOrdenCompra: number, rowVersion?: string | null) => {
  const respuesta = await api.put<RespuestaApi<OrdenCompraConsulta>>('/api/OrdenesCompra/AprobarOrdenCompra',
    { idOrdenCompra, rowVersion: rowVersion ?? null })
  return respuesta.data
}

// Eliminar = anulación lógica con motivo
export const eliminarOrdenCompra = async (codigoOrdenCompra: number, motivo: string, rowVersion?: string | null) => {
  const respuesta = await api.delete<RespuestaApi<OrdenCompraConsulta>>(
    `/api/OrdenesCompra/EliminarOrdenCompra/${codigoOrdenCompra}`,
    { params: limpiarParametros({ motivo, rowVersion }) })
  return respuesta.data
}

// Proceso integrado: recepción → inventario → cuenta por pagar
export const recibirOrdenCompra = async (recepcion: RecepcionAgregar) => {
  const respuesta = await api.post<RespuestaApi<RecepcionConsulta>>('/api/OrdenesCompra/RecibirOrdenCompra', recepcion)
  return respuesta.data
}
