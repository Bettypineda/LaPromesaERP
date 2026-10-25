import { consultarProveedores } from './proveedorService'
import type { ProveedorConsulta } from '../interfaces/Proveedor'

// Lista corta de proveedores para los selectores (máximo 100 por consulta)
export const listarProveedores = async (soloActivos: boolean): Promise<ProveedorConsulta[]> => {
  try {
    const r = await consultarProveedores({
      estado: soloActivos ? 'Activo' : undefined, ordenarPor: 'Nombre', direccion: 'ASC', pagina: 1, tamanoPagina: 100,
    })
    return r.exito ? r.datos.registros : []
  } catch {
    return []
  }
}
