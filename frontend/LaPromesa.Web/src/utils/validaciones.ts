// Validaciones del lado del cliente: mismas reglas que el backend (ValidacionesDTO.cs) y la base de datos.

// NIT de Guatemala con dígito verificador módulo 11 (igual que compras.fn_NitValido)
export const nitValido = (texto: string) => {
  const n = texto.trim().replace(/[-\s]/g, '').toUpperCase()
  if (n.length < 2 || n.length > 13) return false
  const cuerpo = n.slice(0, -1)
  const dv = n.slice(-1)
  if (!/^\d+$/.test(cuerpo)) return false
  let suma = 0
  for (let i = 0; i < cuerpo.length; i++) suma += Number(cuerpo[i]) * (cuerpo.length - i + 1)
  const r = (11 - (suma % 11)) % 11
  return r === 10 ? dv === 'K' : dv === String(r)
}

// Teléfono de Guatemala: 8 dígitos que inician con 2-7 (acepta guion, espacios o +502)
export const telefonoValido = (texto: string) => {
  let t = texto.replace(/[\s\-()]/g, '')
  if (t.startsWith('+502')) t = t.substring(4)
  return /^[2-7]\d{7}$/.test(t)
}

export const correoValido = (texto: string) => /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(texto.trim())

export type Errores = Record<string, string>

export const hayErrores = (errores: Errores) => Object.keys(errores).length > 0
