import { AxiosError } from 'axios'
import { URL_API } from '../services/api'

export interface ErrorApi {
  mensaje: string
  campos: Record<string, string>
}

// Convierte cualquier error de Axios en un mensaje claro para el usuario
// y, si el backend devolvió errores de validación, los asocia a cada campo.
export const leerError = (error: unknown, porDefecto = 'No se pudo completar la operación.'): ErrorApi => {
  const campos: Record<string, string> = {}
  if (error instanceof AxiosError) {
    if (!error.response) {
      return { mensaje: `No fue posible comunicarse con la API (${URL_API || 'backend local'}). Verifique que el backend esté encendido.`, campos }
    }
    const { status, data } = error.response
    if (status === 403) {
      return { mensaje: 'Su rol no tiene permiso para realizar esta acción.', campos }
    }
    if (data && typeof data === 'object' && 'mensaje' in data) {
      const cuerpo = data as { mensaje: string; detalle?: string | null; datos?: unknown }
      if (status === 400 && cuerpo.datos && typeof cuerpo.datos === 'object' && !Array.isArray(cuerpo.datos)) {
        for (const [clave, valor] of Object.entries(cuerpo.datos as Record<string, unknown>)) {
          if (!Array.isArray(valor) || valor.length === 0) continue
          const campo = clave.replace(/^\$\./, '').split('.').pop() ?? clave
          campos[campo.charAt(0).toLowerCase() + campo.slice(1)] = String(valor[0])
        }
      }
      // En errores 500 (solo en Development) el backend envía el detalle técnico
      const detalle = status >= 500 && cuerpo.detalle ? ` (${cuerpo.detalle})` : ''
      return { mensaje: `${cuerpo.mensaje}${Object.keys(campos).length ? '' : detalle}`, campos }
    }
    if (status === 401) return { mensaje: 'Su sesión venció. Inicie sesión de nuevo.', campos }
    if (status === 404) return { mensaje: 'El registro no existe.', campos }
  }
  return { mensaje: porDefecto, campos }
}
