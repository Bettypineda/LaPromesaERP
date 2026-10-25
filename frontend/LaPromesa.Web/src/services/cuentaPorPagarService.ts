import api, { limpiarParametros } from './api'
import type { RespuestaApi, ResultadoPaginado } from '../interfaces/RespuestaApi'
import type {
  CuentaPorPagarConsulta, CuentaPorPagarDetalle, CuentaPorPagarFiltro, PagoAgregar, PagoConsulta,
} from '../interfaces/CuentaPorPagar'

export const consultarCuentasPorPagar = async (filtro: Partial<CuentaPorPagarFiltro>) => {
  // soloConSaldo es true por defecto en el backend: se envía siempre explícito
  const { soloConSaldo, ...resto } = filtro
  const respuesta = await api.get<RespuestaApi<ResultadoPaginado<CuentaPorPagarConsulta>>>(
    '/api/CuentasPorPagar/ConsultarCuentasPorPagar',
    { params: { ...limpiarParametros(resto), soloConSaldo: soloConSaldo ?? true } })
  return respuesta.data
}

export const buscarCuentaPorPagar = async (codigoCuentaPagar: number) => {
  const respuesta = await api.get<RespuestaApi<CuentaPorPagarDetalle>>(`/api/CuentasPorPagar/BuscarCuentaPorPagar/${codigoCuentaPagar}`)
  return respuesta.data
}

// Transferencia: el backend la envía a la API bancaria externa (BancoSimulado.API)
export const pagarCuentaPorPagar = async (pago: PagoAgregar) => {
  const respuesta = await api.post<RespuestaApi<PagoConsulta>>('/api/CuentasPorPagar/PagarCuentaPorPagar', pago)
  return respuesta.data
}

export const consultarPagosPendientes = async () => {
  const respuesta = await api.get<RespuestaApi<PagoConsulta[]>>('/api/CuentasPorPagar/ConsultarPagosPendientes')
  return respuesta.data
}

export const reintentarPago = async (codigoPago: number) => {
  const respuesta = await api.put<RespuestaApi<PagoConsulta>>(`/api/CuentasPorPagar/ReintentarPago/${codigoPago}`)
  return respuesta.data
}
