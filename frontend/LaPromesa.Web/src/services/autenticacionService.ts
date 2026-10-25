import api from './api'
import type { RespuestaApi } from '../interfaces/RespuestaApi'
import type { IniciarSesion, Token, UsuarioSesion } from '../interfaces/Autenticacion'

export const iniciarSesion = async (datos: IniciarSesion) => {
  const respuesta = await api.post<RespuestaApi<Token>>('/api/Autenticacion/IniciarSesion', datos)
  return respuesta.data
}

export const cerrarSesion = async (refreshToken: string) => {
  const respuesta = await api.post<RespuestaApi<boolean>>('/api/Autenticacion/CerrarSesion', { refreshToken })
  return respuesta.data
}

export const consultarUsuarioActual = async () => {
  const respuesta = await api.get<RespuestaApi<UsuarioSesion>>('/api/Autenticacion/UsuarioActual')
  return respuesta.data
}
