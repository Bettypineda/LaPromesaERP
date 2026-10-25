import type { RecepcionConsulta } from './Recepcion'

export type EstadoOrden = 'Pendiente' | 'Aprobada' | 'Parcial' | 'Recibida' | 'Anulada'

export interface OrdenCompraLinea {
  idDetalle: number
  idOrdenCompra: number
  numeroOrden: string | null
  idProducto: number
  codigoProducto: string | null
  producto: string | null
  unidadMedida: string | null
  cantidadPedida: number
  cantidadRecibida: number
  cantidadPendiente: number
  costoUnitario: number
  subtotal: number
}

export interface OrdenCompraConsulta {
  idOrdenCompra: number
  numero: string
  idProveedor: number
  codigoProveedor: string
  proveedor: string
  nitProveedor: string
  idBodega: number
  bodega: string
  fechaOrden: string
  fechaEsperada: string
  tipoPago: string
  diasCredito: number
  observaciones: string | null
  subtotal: number
  tasaIva: number
  iva: number
  total: number
  estado: EstadoOrden
  fechaCreacion: string
  creadoPor: string
  fechaModificacion: string | null
  modificadoPor: string | null
  fechaAprobacion: string | null
  aprobadoPor: string | null
  fechaAnulacion: string | null
  anuladoPor: string | null
  motivoAnulacion: string | null
  rowVersion: string | null
  lineas: number
  cantidadPedida: number
  cantidadRecibida: number
  porcentajeRecibido: number
  recepciones: number
  totalRecibido: number
  diasParaEntrega: number
  estaAtrasada: boolean
}

export interface OrdenCompraFiltro {
  buscar?: string
  estado?: string
  idProveedor?: number
  idBodega?: number
  fechaDesde?: string
  fechaHasta?: string
  soloAtrasadas?: boolean
  ordenarPor: string
  direccion: 'ASC' | 'DESC'
  pagina: number
  tamanoPagina: number
}

export interface LineaOrdenAgregar {
  idProducto: number
  cantidadPedida: number
  costoUnitario: number
}

export interface OrdenCompraAgregar {
  idProveedor: number
  idBodega: number
  fechaEsperada: string
  observaciones: string
  lineas: LineaOrdenAgregar[]
}

export interface OrdenCompraEditar extends OrdenCompraAgregar {
  idOrdenCompra: number
  rowVersion: string | null
}

export interface HistorialOrden {
  estadoAnterior: string | null
  estadoNuevo: string
  fecha: string
  usuario: string
  comentario: string | null
}

export interface OrdenCompraDetalle {
  orden: OrdenCompraConsulta
  lineas: OrdenCompraLinea[]
  recepciones: RecepcionConsulta[]
  historial: HistorialOrden[]
}
