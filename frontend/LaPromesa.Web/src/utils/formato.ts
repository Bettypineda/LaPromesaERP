const moneda = new Intl.NumberFormat('es-GT', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
const numero = new Intl.NumberFormat('es-GT', { maximumFractionDigits: 2 })

export const formatoMoneda = (valor: number | null | undefined) =>
  valor === null || valor === undefined || Number.isNaN(valor) ? '—' : `Q ${moneda.format(valor)}`

export const formatoNumero = (valor: number | null | undefined) =>
  valor === null || valor === undefined ? '—' : numero.format(valor)

export const formatoPorcentaje = (valor: number | null | undefined) =>
  valor === null || valor === undefined ? '—' : `${numero.format(valor)} %`

const MESES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic']

// "2026-10-24" o "2026-10-24T13:05:00" → "24 oct 2026" (sin desfase de zona horaria)
export const formatoFecha = (valor: string | null | undefined) => {
  if (!valor) return '—'
  const [a, m, d] = valor.substring(0, 10).split('-').map(Number)
  if (!a || !m || !d) return valor
  return `${d} ${MESES[m - 1]} ${a}`
}

export const formatoFechaHora = (valor: string | null | undefined) => {
  if (!valor) return '—'
  const fecha = new Date(valor)
  if (Number.isNaN(fecha.getTime())) return valor
  return `${formatoFecha(valor)}, ${fecha.toLocaleTimeString('es-GT', { hour: '2-digit', minute: '2-digit' })}`
}

// Fecha local en formato yyyy-mm-dd (para inputs type="date")
export const hoyIso = (desplazamientoDias = 0) => {
  const f = new Date()
  f.setDate(f.getDate() + desplazamientoDias)
  const mm = String(f.getMonth() + 1).padStart(2, '0')
  const dd = String(f.getDate()).padStart(2, '0')
  return `${f.getFullYear()}-${mm}-${dd}`
}

export const primerDiaDelMes = () => hoyIso().substring(0, 8) + '01'

// Identificador único por intento de pago (idempotencia)
export const nuevoGuid = (): string => {
  if (typeof crypto !== 'undefined' && 'randomUUID' in crypto) return crypto.randomUUID()
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0
    return (c === 'x' ? r : (r & 0x3) | 0x8).toString(16)
  })
}
