import type { CuentaPorPagarConsulta } from './CuentaPorPagar'
import type { OrdenCompraConsulta } from './OrdenCompra'

export type TipoPago = 'Contado' | 'Credito'

export interface ProveedorConsulta {
  idProveedor: number
  codigo: string
  nombre: string
  nit: string
  idCategoria: number
  categoria: string
  contacto: string | null
  telefono: string | null
  email: string | null
  direccion: string | null
  departamento: string | null
  tipoPago: TipoPago
  diasCredito: number
  limiteCredito: number
  banco: string | null
  numeroCuenta: string | null
  estado: 'Activo' | 'Inactivo'
  fechaCreacion: string
  creadoPor: string
  fechaModificacion: string | null
  modificadoPor: string | null
  fechaInactivacion: string | null
  inactivadoPor: string | null
  motivoInactivacion: string | null
  rowVersion: string | null
  ordenesAbiertas: number
  saldoPendiente: number
  creditoDisponible: number | null
  ultimaCompra: string | null
}

export interface ProveedorFiltro {
  buscar?: string
  estado?: string
  tipoPago?: string
  idCategoria?: number
  ordenarPor: string
  direccion: 'ASC' | 'DESC'
  pagina: number
  tamanoPagina: number
}

export interface ProveedorAgregar {
  nombre: string
  nit: string
  idCategoria: number
  contacto: string
  telefono: string
  email: string
  direccion: string
  departamento: string
  tipoPago: TipoPago
  diasCredito: number
  limiteCredito: number
  banco: string
  numeroCuenta: string
}

export interface ProveedorEditar extends ProveedorAgregar {
  idProveedor: number
  rowVersion: string | null
}

export interface Cumplimiento {
  totalRecepciones: number
  aTiempo: number
  retraso: number
  anticipada: number
  porcentajeCumplimiento: number | null
}

export interface ProveedorDetalle {
  proveedor: ProveedorConsulta
  ultimasOrdenes: OrdenCompraConsulta[]
  cuentasPorPagar: CuentaPorPagarConsulta[]
  cumplimiento: Cumplimiento | null
}
