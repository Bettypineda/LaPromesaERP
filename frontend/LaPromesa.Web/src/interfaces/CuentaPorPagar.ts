export interface CuentaPorPagarConsulta {
  idCuentaPagar: number
  numero: string
  idRecepcion: number
  numeroRecepcion: string
  idOrdenCompra: number
  numeroOrden: string
  facturaProveedor: string
  idProveedor: number
  codigoProveedor: string
  proveedor: string
  nitProveedor: string
  banco: string | null
  numeroCuenta: string | null
  fechaEmision: string
  fechaVencimiento: string
  monto: number
  saldo: number
  estado: 'Pendiente' | 'Parcial' | 'Pagada'
  montoEnProceso: number
  saldoDisponible: number
  diasVencida: number
  rangoAntiguedad: string
  fechaCreacion: string
  fechaModificacion: string | null
  rowVersion: string | null
}

export interface CuentaPorPagarFiltro {
  idProveedor?: number
  estado?: string
  soloVencidas?: boolean
  soloConSaldo?: boolean
  venceDesde?: string
  venceHasta?: string
  pagina: number
  tamanoPagina: number
}

export type MetodoPago = 'Transferencia' | 'Cheque' | 'Efectivo'

export interface PagoConsulta {
  idPago: number
  numero: string
  operacionId: string
  idCuentaPagar: number
  numeroCuentaPagar: string
  idProveedor: number
  proveedor: string
  monto: number
  metodo: MetodoPago
  banco: string | null
  cuentaDestino: string | null
  referenciaBanco: string | null
  estado: 'Pendiente' | 'Aprobado' | 'Rechazado'
  mensajeBanco: string | null
  intentos: number
  fechaSolicitud: string
  fechaConfirmacion: string | null
  registradoPor: string
  confirmadoPor: string | null
}

export interface PagoAgregar {
  idCuentaPagar: number
  operacionId: string
  monto: number
  metodo: MetodoPago
  banco: string
  cuentaDestino: string
  referencia: string
}

export interface CuentaPorPagarDetalle {
  cuenta: CuentaPorPagarConsulta
  pagos: PagoConsulta[]
}
