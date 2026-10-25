import api, { limpiarParametros } from './api'
import type { RespuestaApi, ResultadoPaginado } from '../interfaces/RespuestaApi'
import type {
  ProveedorAgregar, ProveedorConsulta, ProveedorDetalle, ProveedorEditar, ProveedorFiltro,
} from '../interfaces/Proveedor'

export const consultarProveedores = async (filtro: Partial<ProveedorFiltro>) => {
  const respuesta = await api.get<RespuestaApi<ResultadoPaginado<ProveedorConsulta>>>(
    '/api/Proveedores/ConsultarProveedores', { params: limpiarParametros(filtro) })
  return respuesta.data
}

export const buscarProveedor = async (codigoProveedor: number) => {
  const respuesta = await api.get<RespuestaApi<ProveedorDetalle>>(`/api/Proveedores/BuscarProveedor/${codigoProveedor}`)
  return respuesta.data
}

export const agregarProveedor = async (proveedor: ProveedorAgregar) => {
  const respuesta = await api.post<RespuestaApi<ProveedorConsulta>>('/api/Proveedores/AgregarProveedor', proveedor)
  return respuesta.data
}

export const editarProveedor = async (proveedor: ProveedorEditar) => {
  const respuesta = await api.put<RespuestaApi<ProveedorConsulta>>('/api/Proveedores/EditarProveedor', proveedor)
  return respuesta.data
}

// Eliminar = inactivación lógica con motivo (el registro no se borra)
export const eliminarProveedor = async (codigoProveedor: number, motivo: string, rowVersion?: string | null) => {
  const respuesta = await api.delete<RespuestaApi<ProveedorConsulta>>(
    `/api/Proveedores/EliminarProveedor/${codigoProveedor}`,
    { params: limpiarParametros({ motivo, rowVersion }) })
  return respuesta.data
}

export const reactivarProveedor = async (codigoProveedor: number, rowVersion?: string | null) => {
  const respuesta = await api.put<RespuestaApi<ProveedorConsulta>>(
    `/api/Proveedores/ReactivarProveedor/${codigoProveedor}`, null,
    { params: limpiarParametros({ rowVersion }) })
  return respuesta.data
}
