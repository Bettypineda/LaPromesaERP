import api, { limpiarParametros } from './api'
import type { RespuestaApi, ResultadoPaginado } from '../interfaces/RespuestaApi'
import type { RecepcionConsulta, RecepcionDetalle, RecepcionFiltro } from '../interfaces/Recepcion'

export const consultarRecepciones = async (filtro: Partial<RecepcionFiltro>) => {
  const respuesta = await api.get<RespuestaApi<ResultadoPaginado<RecepcionConsulta>>>(
    '/api/Recepciones/ConsultarRecepciones', { params: limpiarParametros(filtro) })
  return respuesta.data
}

export const buscarRecepcion = async (codigoRecepcion: number) => {
  const respuesta = await api.get<RespuestaApi<RecepcionDetalle>>(`/api/Recepciones/BuscarRecepcion/${codigoRecepcion}`)
  return respuesta.data
}
