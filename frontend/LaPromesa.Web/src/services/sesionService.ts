import type { Token, UsuarioSesion } from '../interfaces/Autenticacion'

// Guarda la sesión (access token, refresh token y usuario) en el navegador.
export interface Sesion {
  accessToken: string
  accessTokenExpira: string
  refreshToken: string
  usuario: UsuarioSesion
}

const CLAVE = 'lapromesa.sesion'

export const obtenerSesion = (): Sesion | null => {
  try {
    const texto = localStorage.getItem(CLAVE)
    return texto ? (JSON.parse(texto) as Sesion) : null
  } catch {
    return null
  }
}

export const guardarSesion = (token: Token) => {
  const sesion: Sesion = {
    accessToken: token.accessToken,
    accessTokenExpira: token.accessTokenExpira,
    refreshToken: token.refreshToken,
    usuario: token.usuario,
  }
  try {
    localStorage.setItem(CLAVE, JSON.stringify(sesion))
  } catch {
    /* almacenamiento no disponible: la sesión dura mientras la pestaña esté abierta */
  }
  return sesion
}

export const limpiarSesion = () => {
  try {
    localStorage.removeItem(CLAVE)
  } catch {
    /* sin almacenamiento */
  }
}
