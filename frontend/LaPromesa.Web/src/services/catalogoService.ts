import api from './api'
import type { RespuestaApi } from '../interfaces/RespuestaApi'
import type { Bodega, CategoriaAgregar, CategoriaConsulta, Producto } from '../interfaces/Catalogos'

export const consultarBodegas = async () => {
  const respuesta = await api.get<RespuestaApi<Bodega[]>>('/api/Catalogos/ConsultarBodegas')
  return respuesta.data
}

export const consultarProductos = async (buscar?: string) => {
  const respuesta = await api.get<RespuestaApi<Producto[]>>('/api/Catalogos/ConsultarProductos', {
    params: buscar ? { buscar } : undefined,
  })
  return respuesta.data
}

export const consultarCategorias = async (soloActivas = true) => {
  const respuesta = await api.get<RespuestaApi<CategoriaConsulta[]>>('/api/Categorias/ConsultarCategorias', {
    params: { soloActivas },
  })
  return respuesta.data
}

export const agregarCategoria = async (categoria: CategoriaAgregar) => {
  const respuesta = await api.post<RespuestaApi<CategoriaConsulta>>('/api/Categorias/AgregarCategoria', categoria)
  return respuesta.data
}
