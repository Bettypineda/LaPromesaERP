import type { TipoReporte } from '../services/reporteService'

export type Formato = 'texto' | 'moneda' | 'numero' | 'porcentaje' | 'fecha' | 'estado'

export interface Columna {
  clave: string
  titulo: string
  formato?: Formato
  total?: boolean
}

export interface Cifra {
  clave: string
  titulo: string
  formato: Formato
}

export interface DefinicionReporte {
  id: 'compras' | 'cumplimiento' | 'cuentas'
  tipo: TipoReporte
  titulo: string
  descripcion: string
  porPeriodo: boolean
  cifras: Cifra[]
  resumenTitulo: string
  resumen: Columna[]
  barra?: { clave: string; titulo: string }
  detalleTitulo: string
  detalle: Columna[]
}

export const REPORTES: DefinicionReporte[] = [
  {
    id: 'compras',
    tipo: 'ReporteComprasPorProveedor',
    titulo: 'Compras por proveedor',
    descripcion: 'Cuánto se ordenó y recibió de cada proveedor en el período, con su participación en el total.',
    porPeriodo: true,
    cifras: [
      { clave: 'total', titulo: 'Total ordenado (con IVA)', formato: 'moneda' },
      { clave: 'totalRecibido', titulo: 'Total recibido', formato: 'moneda' },
      { clave: 'ordenes', titulo: 'Órdenes', formato: 'numero' },
      { clave: 'proveedores', titulo: 'Proveedores', formato: 'numero' },
    ],
    resumenTitulo: 'Resumen por proveedor',
    resumen: [
      { clave: 'proveedor', titulo: 'Proveedor' },
      { clave: 'categoria', titulo: 'Categoría' },
      { clave: 'cantidadOrdenes', titulo: 'Órdenes', formato: 'numero', total: true },
      { clave: 'ordenesAnuladas', titulo: 'Anuladas', formato: 'numero', total: true },
      { clave: 'totalOrdenado', titulo: 'Ordenado', formato: 'moneda', total: true },
      { clave: 'totalRecibido', titulo: 'Recibido', formato: 'moneda', total: true },
      { clave: 'pendienteDeRecibir', titulo: 'Por recibir', formato: 'moneda', total: true },
      { clave: 'promedioPorOrden', titulo: 'Promedio', formato: 'moneda' },
      { clave: 'ultimaOrden', titulo: 'Última orden', formato: 'fecha' },
    ],
    barra: { clave: 'porcentajeParticipacion', titulo: 'Participación' },
    detalleTitulo: 'Órdenes del período',
    detalle: [
      { clave: 'numero', titulo: 'Orden' },
      { clave: 'fechaOrden', titulo: 'Fecha', formato: 'fecha' },
      { clave: 'proveedor', titulo: 'Proveedor' },
      { clave: 'bodega', titulo: 'Bodega' },
      { clave: 'estado', titulo: 'Estado', formato: 'estado' },
      { clave: 'subtotal', titulo: 'Subtotal', formato: 'moneda', total: true },
      { clave: 'iva', titulo: 'IVA', formato: 'moneda', total: true },
      { clave: 'total', titulo: 'Total', formato: 'moneda', total: true },
      { clave: 'totalRecibido', titulo: 'Recibido', formato: 'moneda', total: true },
    ],
  },
  {
    id: 'cumplimiento',
    tipo: 'ReporteCumplimientoProveedores',
    titulo: 'Cumplimiento de entregas',
    descripcion: 'Qué proveedores entregan a tiempo, antes o con retraso, y su calificación en el período.',
    porPeriodo: true,
    cifras: [
      { clave: 'porcentajeCumplimiento', titulo: 'Cumplimiento general', formato: 'porcentaje' },
      { clave: 'recepciones', titulo: 'Recepciones', formato: 'numero' },
      { clave: 'aTiempo', titulo: 'A tiempo', formato: 'numero' },
      { clave: 'conRetraso', titulo: 'Con retraso', formato: 'numero' },
    ],
    resumenTitulo: 'Calificación por proveedor',
    resumen: [
      { clave: 'proveedor', titulo: 'Proveedor' },
      { clave: 'categoria', titulo: 'Categoría' },
      { clave: 'totalRecepciones', titulo: 'Recepciones', formato: 'numero', total: true },
      { clave: 'aTiempo', titulo: 'A tiempo', formato: 'numero', total: true },
      { clave: 'anticipadas', titulo: 'Anticipadas', formato: 'numero', total: true },
      { clave: 'conRetraso', titulo: 'Con retraso', formato: 'numero', total: true },
      { clave: 'promedioDiasRetraso', titulo: 'Retraso prom. (días)', formato: 'numero' },
      { clave: 'ordenesAtrasadasHoy', titulo: 'Atrasadas hoy', formato: 'numero', total: true },
      { clave: 'calificacion', titulo: 'Calificación', formato: 'estado' },
    ],
    barra: { clave: 'porcentajeCumplimiento', titulo: 'Cumplimiento' },
    detalleTitulo: 'Recepciones del período',
    detalle: [
      { clave: 'numero', titulo: 'Recepción' },
      { clave: 'numeroOrden', titulo: 'Orden' },
      { clave: 'proveedor', titulo: 'Proveedor' },
      { clave: 'fechaEsperada', titulo: 'Esperada', formato: 'fecha' },
      { clave: 'fechaRecepcion', titulo: 'Recibida', formato: 'fecha' },
      { clave: 'diasDiferencia', titulo: 'Diferencia (días)', formato: 'numero' },
      { clave: 'cumplimiento', titulo: 'Cumplimiento', formato: 'estado' },
      { clave: 'total', titulo: 'Total', formato: 'moneda', total: true },
    ],
  },
  {
    id: 'cuentas',
    tipo: 'ReporteCuentasPorPagar',
    titulo: 'Antigüedad de cuentas por pagar',
    descripcion: 'Saldos pendientes con cada proveedor a la fecha de corte, agrupados por días de vencimiento.',
    porPeriodo: false,
    cifras: [
      { clave: 'saldoTotal', titulo: 'Saldo total', formato: 'moneda' },
      { clave: 'porVencer', titulo: 'Por vencer', formato: 'moneda' },
      { clave: 'vencido_1_30', titulo: 'Vencido 1 a 30 días', formato: 'moneda' },
      { clave: 'vencido_Mas_90', titulo: 'Vencido más de 90 días', formato: 'moneda' },
    ],
    resumenTitulo: 'Saldos por proveedor',
    resumen: [
      { clave: 'proveedor', titulo: 'Proveedor' },
      { clave: 'diasCredito', titulo: 'Crédito (días)', formato: 'numero' },
      { clave: 'documentos', titulo: 'Documentos', formato: 'numero', total: true },
      { clave: 'porVencer', titulo: 'Por vencer', formato: 'moneda', total: true },
      { clave: 'vencido_1_30', titulo: '1–30', formato: 'moneda', total: true },
      { clave: 'vencido_31_60', titulo: '31–60', formato: 'moneda', total: true },
      { clave: 'vencido_61_90', titulo: '61–90', formato: 'moneda', total: true },
      { clave: 'vencido_Mas_90', titulo: '+90', formato: 'moneda', total: true },
      { clave: 'saldoTotal', titulo: 'Saldo', formato: 'moneda', total: true },
      { clave: 'proximoVencimiento', titulo: 'Próximo vencimiento', formato: 'fecha' },
    ],
    detalleTitulo: 'Documentos pendientes',
    detalle: [
      { clave: 'numero', titulo: 'Cuenta' },
      { clave: 'facturaProveedor', titulo: 'Factura' },
      { clave: 'proveedor', titulo: 'Proveedor' },
      { clave: 'fechaEmision', titulo: 'Emitida', formato: 'fecha' },
      { clave: 'fechaVencimiento', titulo: 'Vence', formato: 'fecha' },
      { clave: 'diasVencida', titulo: 'Días vencida', formato: 'numero' },
      { clave: 'rango', titulo: 'Rango' },
      { clave: 'monto', titulo: 'Monto', formato: 'moneda', total: true },
      { clave: 'saldoAlCorte', titulo: 'Saldo al corte', formato: 'moneda', total: true },
    ],
  },
]
