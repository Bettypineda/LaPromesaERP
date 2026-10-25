export type Cumplimiento = 'ATiempo' | 'Retraso' | 'Anticipada'

export interface RecepcionLinea {
  idRecepcionDetalle: number
  idDetalleOrden: number
  idProducto: number
  codigoProducto: string | null
  producto: string | null
  unidadMedida: string | null
  cantidad: number
  costoUnitario: number
  subtotal: number
}

export interface RecepcionConsulta {
  idRecepcion: number
  numero: string
  idOrdenCompra: number
  numeroOrden: string
  idProveedor: number
  proveedor: string
  nitProveedor: string
  idBodega: number
  bodega: string
  fechaRecepcion: string
  fechaEsperada: string
  cumplimiento: Cumplimiento
  diasDiferencia: number
  serieFactura: string | null
  numeroFactura: string
  factura: string
  subtotal: number
  iva: number
  total: number
  observaciones: string | null
  fechaCreacion: string
  recibidoPor: string
  idCuentaPagar: number | null
  numeroCuentaPagar: string | null
}

export interface RecepcionFiltro {
  idOrdenCompra?: number
  idProveedor?: number
  cumplimiento?: string
  fechaDesde?: string
  fechaHasta?: string
  pagina: number
  tamanoPagina: number
}

export interface LineaRecepcionAgregar {
  idDetalle: number
  cantidad: number
}

export interface RecepcionAgregar {
  idOrdenCompra: number
  fechaRecepcion: string
  serieFactura: string
  numeroFactura: string
  observaciones: string
  lineas: LineaRecepcionAgregar[]
}

export interface RecepcionDetalle {
  recepcion: RecepcionConsulta
  lineas: RecepcionLinea[]
}
