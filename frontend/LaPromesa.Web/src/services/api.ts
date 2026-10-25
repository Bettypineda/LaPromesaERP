import axios, { AxiosError, type InternalAxiosRequestConfig } from 'axios'
import type { RespuestaApi } from '../interfaces/RespuestaApi'
import type { Token } from '../interfaces/Autenticacion'
import { guardarSesion, limpiarSesion, obtenerSesion } from './sesionService'

// URL del backend: se configura en .env.development (VITE_API_URL)
export const URL_API = import.meta.env.VITE_API_URL ?? 'http://localhost:5000'

const api = axios.create({
  baseURL: URL_API,
  timeout: 30000,
})

// Los textos opcionales vacíos se envían como null (así el backend no los valida ni guarda cadenas vacías)
const vaciosANull = (valor: unknown): unknown => {
  if (valor === '') return null
  if (Array.isArray(valor)) return valor.map(vaciosANull)
  if (valor && typeof valor === 'object' && Object.getPrototypeOf(valor) === Object.prototype) {
    return Object.fromEntries(Object.entries(valor).map(([k, v]) => [k, vaciosANull(v)]))
  }
  return valor
}

// 1) A cada petición se le agrega el access token (JWT)
api.interceptors.request.use((config) => {
  if (config.data) config.data = vaciosANull(config.data)
  const sesion = obtenerSesion()
  if (sesion?.accessToken) {
    config.headers.Authorization = `Bearer ${sesion.accessToken}`
  }
  return config
})

// 2) Si el access token venció (401), se renueva una sola vez con el refresh token y se repite la petición
let renovacionEnCurso: Promise<string | null> | null = null

const renovarToken = async (): Promise<string | null> => {
  const sesion = obtenerSesion()
  if (!sesion?.refreshToken) return null
  try {
    const respuesta = await axios.post<RespuestaApi<Token>>(
      `${URL_API}/api/Autenticacion/RenovarToken`,
      { refreshToken: sesion.refreshToken }
    )
    if (respuesta.data.exito) {
      return guardarSesion(respuesta.data.datos).accessToken
    }
  } catch {
    /* refresh vencido, revocado o reutilizado */
  }
  return null
}

type ConfigConReintento = InternalAxiosRequestConfig & { _reintento?: boolean }

api.interceptors.response.use(
  (respuesta) => respuesta,
  async (error: AxiosError) => {
    const config = error.config as ConfigConReintento | undefined
    const esAutenticacion = config?.url?.includes('/api/Autenticacion/IniciarSesion')
      || config?.url?.includes('/api/Autenticacion/RenovarToken')

    if (error.response?.status === 401 && config && !config._reintento && !esAutenticacion) {
      config._reintento = true
      if (!renovacionEnCurso) {
        renovacionEnCurso = renovarToken().finally(() => {
          renovacionEnCurso = null
        })
      }
      const nuevoToken = await renovacionEnCurso
      if (nuevoToken) {
        config.headers.Authorization = `Bearer ${nuevoToken}`
        return api(config)
      }
      limpiarSesion()
      window.dispatchEvent(new Event('lapromesa:sesion-expirada'))
    }
    return Promise.reject(error)
  }
)

// Quita los filtros vacíos antes de enviarlos en la URL
export const limpiarParametros = (filtro: object) =>
  Object.fromEntries(
    Object.entries(filtro).filter(([, v]) => v !== undefined && v !== null && v !== '' && v !== false)
  )

export default api
