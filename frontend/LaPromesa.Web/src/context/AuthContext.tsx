import { createContext, useCallback, useEffect, useMemo, useState, type ReactNode } from 'react'
import type { UsuarioSesion } from '../interfaces/Autenticacion'
import { cerrarSesion as cerrarSesionApi, iniciarSesion as iniciarSesionApi } from '../services/autenticacionService'
import { guardarSesion, limpiarSesion, obtenerSesion } from '../services/sesionService'
import { tienePermiso, type Permiso } from '../utils/roles'

export interface ContextoAuth {
  usuario: UsuarioSesion | null
  sesionExpirada: boolean
  cierreManual: boolean
  iniciarSesion: (usuario: string, contrasena: string) => Promise<void>
  cerrarSesion: () => Promise<void>
  puede: (permiso: Permiso) => boolean
}

export const AuthContext = createContext<ContextoAuth | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [usuario, setUsuario] = useState<UsuarioSesion | null>(() => obtenerSesion()?.usuario ?? null)
  const [sesionExpirada, setSesionExpirada] = useState(false)
  // true cuando el usuario cerró sesión con el botón: el siguiente ingreso empieza en Inicio
  const [cierreManual, setCierreManual] = useState(false)

  // El interceptor de Axios avisa cuando ni el refresh token sirve: se vuelve al login
  useEffect(() => {
    const alExpirar = () => {
      setUsuario(null)
      setSesionExpirada(true)
    }
    window.addEventListener('lapromesa:sesion-expirada', alExpirar)
    return () => window.removeEventListener('lapromesa:sesion-expirada', alExpirar)
  }, [])

  const iniciarSesion = useCallback(async (nombreUsuario: string, contrasena: string) => {
    const respuesta = await iniciarSesionApi({ usuario: nombreUsuario, contrasena })
    if (!respuesta.exito) throw new Error(respuesta.mensaje)
    const sesion = guardarSesion(respuesta.datos)
    setSesionExpirada(false)
    setCierreManual(false)
    setUsuario(sesion.usuario)
  }, [])

  const cerrarSesion = useCallback(async () => {
    const sesion = obtenerSesion()
    try {
      if (sesion?.refreshToken) await cerrarSesionApi(sesion.refreshToken)
    } catch {
      /* aunque falle la API, la sesión local se cierra */
    }
    limpiarSesion()
    setCierreManual(true)
    setUsuario(null)
  }, [])

  const puede = useCallback((permiso: Permiso) => tienePermiso(usuario?.rol, permiso), [usuario])

  const valor = useMemo(
    () => ({ usuario, sesionExpirada, cierreManual, iniciarSesion, cerrarSesion, puede }),
    [usuario, sesionExpirada, cierreManual, iniciarSesion, cerrarSesion, puede]
  )

  return <AuthContext.Provider value={valor}>{children}</AuthContext.Provider>
}
