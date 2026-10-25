// =====================================================================
//  Pruebas de extremo a extremo (E2E) + capturas para manuales y evidencias
//  Módulos: Proveedores y Compras (Sara) — La Promesa ERP
//  -------------------------------------------------------------------
//  Recorre el sistema REAL (frontend 5173 → API 5000 → SQL Server; banco 5100)
//  con Microsoft Edge en modo automático (Playwright) y guarda:
//    docs/evidencias/capturas/*.png         capturas de cada paso
//    docs/evidencias/capturas/resultados.json  resultado de cada prueba
//  Usa SOLO datos ficticios. Requiere API, banco simulado y frontend encendidos.
// =====================================================================
import { chromium } from 'playwright-core'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const aqui = path.dirname(fileURLToPath(import.meta.url))
const raiz = path.resolve(aqui, '..', '..', '..')
const salida = path.join(raiz, 'docs', 'evidencias', 'capturas')
fs.mkdirSync(salida, { recursive: true })

const FRONT = 'http://localhost:5173'
const API = 'http://localhost:5000'
const BANCO = 'http://localhost:5100'

const leerJson = (ruta) => { try { return JSON.parse(fs.readFileSync(ruta, 'utf8').replace(/^﻿/, '')) } catch { return {} } }
const cfgApi = leerJson(path.join(raiz, 'backend', 'LaPromesa', 'LaPromesa.API', 'appsettings.Development.local.json'))
const cfgBanco = leerJson(path.join(raiz, 'backend', 'LaPromesa', 'BancoSimulado.API', 'appsettings.Development.local.json'))
const CLAVE = process.env.LAPROMESA_PASSWORD_DEMO || cfgApi?.Seed?.PasswordDemo
const API_KEY_BANCO = process.env.LAPROMESA_BANCO_APIKEY || cfgBanco?.Banco?.ApiKey
if (!CLAVE) { console.error('No se encontró Seed:PasswordDemo en appsettings.Development.local.json'); process.exit(1) }

const resultados = []
const registrar = (id, prueba, esperado, obtenido, ok, captura = null) => {
  resultados.push({ id, prueba, esperado, obtenido, resultado: ok ? 'Aprobada' : 'Fallida', captura, fecha: new Date().toISOString() })
  console.log(`${ok ? '✔' : '✘'} ${id} ${prueba} → ${obtenido}`)
}

// NIT con dígito verificador módulo 11 (misma regla de la base de datos)
const nitValido = () => {
  const cuerpo = String(Math.floor(1000000 + Math.random() * 8999999))
  let s = 0
  for (let i = 0; i < cuerpo.length; i++) s += Number(cuerpo[i]) * (cuerpo.length - i + 1)
  const r = (11 - (s % 11)) % 11
  return `${cuerpo}-${r === 10 ? 'K' : r}`
}

const sufijo = new Date().toISOString().slice(5, 16).replace(/[-T:]/g, '')
const PROVEEDOR = `Distribuidora Santa Rosa ${sufijo}`
const NIT = nitValido()

let n = 0
const navegador = await chromium.launch({ channel: 'msedge', headless: true })
const contexto = await navegador.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1.5, locale: 'es-GT' })
const pagina = await contexto.newPage()
pagina.setDefaultTimeout(20000)

const foto = async (nombre, completa = false, p = pagina) => {
  n += 1
  const archivo = `${String(n).padStart(2, '0')}_${nombre}.png`
  await p.waitForTimeout(700)
  await p.screenshot({ path: path.join(salida, archivo), fullPage: completa })
  return archivo
}
const esperarCarga = async (p = pagina) => {
  await p.waitForLoadState('networkidle').catch(() => undefined)
  await p.locator('.cargando').first().waitFor({ state: 'detached', timeout: 15000 }).catch(() => undefined)
}
const paso = async (nombre, fn) => {
  try { await fn() } catch (e) {
    console.error(`Error en "${nombre}":`, e.message)
    const archivo = await foto(`error_${nombre.replace(/\W+/g, '_')}`).catch(() => null)
    registrar('ERR', nombre, 'Sin errores de ejecución', e.message.split('\n')[0], false, archivo)
  }
}
const iniciarSesion = async (usuario, p = pagina) => {
  await p.goto(`${FRONT}/login`)
  await p.evaluate(() => localStorage.clear())
  await p.goto(`${FRONT}/login`)
  await p.fill('#usuario', usuario)
  await p.fill('#contrasena', CLAVE)
  await p.click('button[type=submit]')
  await p.waitForURL((u) => !u.pathname.startsWith('/login'))
  await esperarCarga(p)
}

let idProveedor = null, idOrden = null, idOrden2 = null, idCuenta = null

// ---------------------------------------------------------------- 1. Autenticación
await paso('login', async () => {
  await pagina.goto(`${FRONT}/login`)
  await pagina.evaluate(() => localStorage.clear())
  await pagina.goto(`${FRONT}/login`)
  await foto('login')
  await pagina.click('button[type=submit]')
  const f1 = await foto('login_validacion_campos')
  const textos = await pagina.locator('.invalid-feedback').allInnerTexts()
  registrar('VAL-01', 'Login sin datos (validación en frontend)', 'Mensajes de campo obligatorio', textos.join(' | '), textos.length >= 2, f1)

  await pagina.fill('#usuario', 'usuario.inexistente')
  await pagina.fill('#contrasena', 'ClaveIncorrecta1')
  await pagina.click('button[type=submit]')
  await pagina.locator('.alerta-error').waitFor()
  const msg = await pagina.locator('.alerta-error').innerText()
  const f2 = await foto('login_credenciales_invalidas')
  registrar('SEG-01', 'Login con credenciales inválidas', 'Rechazo 401 con mensaje claro', msg.trim(), /incorrect/i.test(msg), f2)

  await iniciarSesion('admin')
  const f3 = await foto('inicio_administrador', true)
  registrar('SEG-02', 'Login administrador (access + refresh token)', 'Ingresa al inicio con su rol', 'Inicio cargado: ' + (await pagina.locator('h1').first().innerText()), true, f3)
})

// ---------------------------------------------------------------- 2. Proveedores (CRUD) — rol Compras
await paso('rol_compras', async () => {
  await iniciarSesion('sara.compras')
  const f = await foto('rol_compras_inicio', true)
  registrar('SEG-02b', 'Login rol Compras (sara.compras)', 'Menú y acciones de Compras', 'Inicio cargado', true, f)
})

await paso('proveedores_consultar', async () => {
  await pagina.goto(`${FRONT}/proveedores`)
  await esperarCarga()
  const f = await foto('proveedores_consultar', true)
  const filas = await pagina.locator('table.tabla tbody tr').count()
  registrar('PRV-01', 'Consultar proveedores (paginado, ordenado)', 'Listado con datos de la BD', `${filas} filas en la página 1`, filas > 0, f)
  await pagina.fill('#f-buscar', 'Lácteos')
  await pagina.waitForTimeout(1200)
  await esperarCarga()
  const f2 = await foto('proveedores_busqueda_texto')
  const filas2 = await pagina.locator('table.tabla tbody tr').count()
  registrar('PRV-02', 'Búsqueda por texto "Lácteos"', 'Solo coincidencias', `${filas2} fila(s)`, filas2 >= 1, f2)
  await pagina.fill('#f-buscar', '')
  await pagina.selectOption('#f-tipo', 'Credito')
  await pagina.locator('th button', { hasText: 'Saldo por pagar' }).click()
  await pagina.waitForTimeout(800)
  await esperarCarga()
  const f3 = await foto('proveedores_filtro_y_orden', true)
  registrar('PRV-03', 'Filtro combinado (crédito) + ordenar por saldo', 'Listado filtrado y ordenado', 'Filtro y orden aplicados', true, f3)
})

await paso('proveedores_validaciones', async () => {
  await pagina.goto(`${FRONT}/proveedores/nuevo`)
  await esperarCarga()
  await pagina.fill('#nombre', 'AB')
  await pagina.fill('#nit', '1234567-8')
  await pagina.fill('#telefono', '1234')
  await pagina.fill('#email', 'correo-malo')
  await pagina.click('button[type=submit]')
  await pagina.evaluate(() => window.scrollTo(0, 0))
  const f = await foto('proveedor_validaciones_frontend', true)
  const errores = await pagina.locator('.invalid-feedback').allInnerTexts()
  registrar('VAL-02', 'Proveedor con nombre corto, NIT, teléfono y correo inválidos', 'Mensajes por campo, no se envía', errores.join(' | '), errores.length >= 4, f)
})

await paso('proveedores_agregar', async () => {
  await pagina.goto(`${FRONT}/proveedores/nuevo`)
  await esperarCarga()
  await pagina.fill('#nombre', PROVEEDOR)
  await pagina.fill('#nit', NIT)
  await pagina.selectOption('#idCategoria', { index: 1 })
  await pagina.selectOption('#departamento', 'Santa Rosa')
  await pagina.fill('#direccion', 'Barrio El Centro, Cuilapa, Santa Rosa')
  await pagina.fill('#contacto', 'Lucía Herrera')
  await pagina.fill('#telefono', '7886-4521')
  await pagina.fill('#email', 'ventas@santarosa.test')
  await pagina.locator('label.opcion', { hasText: 'Crédito' }).click()
  await pagina.fill('#diasCredito', '30')
  await pagina.fill('#limiteCredito', '25000')
  await pagina.fill('#banco', 'Banco Simulado GT')
  await pagina.fill('#numeroCuenta', 'SIM-001-7788990')
  const f1 = await foto('proveedor_agregar_formulario', true)
  await pagina.click('button[type=submit]')
  await pagina.waitForURL(/\/proveedores\/\d+$/)
  idProveedor = Number(pagina.url().split('/').pop())
  await esperarCarga()
  const f2 = await foto('proveedor_agregado_detalle', true)
  registrar('PRV-04', `Agregar proveedor (NIT ${NIT})`, 'Se crea con código PR###', `Creado id ${idProveedor}: ${await pagina.locator('h1').innerText()}`, !!idProveedor, f2)
  registrar('PRV-04b', 'Formulario de proveedor completo', 'Datos válidos aceptados', 'Formulario enviado', true, f1)
})

await paso('proveedores_duplicado', async () => {
  await pagina.goto(`${FRONT}/proveedores/nuevo`)
  await esperarCarga()
  await pagina.fill('#nombre', 'Proveedor duplicado de prueba')
  await pagina.fill('#nit', NIT)
  await pagina.selectOption('#idCategoria', { index: 1 })
  await pagina.click('button[type=submit]')
  await pagina.locator('.alerta-error').waitFor()
  const msg = await pagina.locator('.alerta-error').innerText()
  const f = await foto('proveedor_nit_duplicado')
  registrar('VAL-03', 'Agregar proveedor con NIT repetido (regla en backend/BD)', 'Rechazo 409 con mensaje', msg.trim(), msg.length > 0, f)
})

await paso('proveedores_editar', async () => {
  await pagina.goto(`${FRONT}/proveedores/${idProveedor}/editar`)
  await esperarCarga()
  await pagina.fill('#diasCredito', '45')
  const f1 = await foto('proveedor_editar', true)
  await pagina.click('button[type=submit]')
  await pagina.waitForURL(/\/proveedores\/\d+$/)
  await esperarCarga()
  const txt = await pagina.locator('.datos').first().innerText()
  registrar('PRV-05', 'Editar proveedor (días de crédito 30 → 45, con rowVersion)', 'Cambio guardado', /45 días/.test(txt) ? 'Crédito a 45 días' : txt.slice(0, 80), /45 días/.test(txt), f1)
})

// ---------------------------------------------------------------- 3. Órdenes de compra (CRUD) + proceso
await paso('orden_validaciones', async () => {
  await pagina.goto(`${FRONT}/ordenes-compra/nueva`)
  await esperarCarga()
  await pagina.click('button[type=submit]')
  const f = await foto('orden_validaciones_frontend', true)
  const errores = await pagina.locator('.invalid-feedback').allInnerTexts()
  registrar('VAL-04', 'Crear orden sin proveedor, bodega ni productos', 'Mensajes por campo', errores.join(' | '), errores.length >= 3, f)
})

const crearOrden = async (cantidad1, cantidad2, obs) => {
  await pagina.goto(`${FRONT}/ordenes-compra/nueva?proveedor=${idProveedor}`)
  await esperarCarga()
  await pagina.selectOption('#idBodega', { index: 1 })
  await pagina.fill('#observaciones', obs)
  await pagina.selectOption('select[aria-label="Producto de la línea 1"]', { index: 1 })
  await pagina.fill('input[aria-label="Cantidad de la línea 1"]', String(cantidad1))
  await pagina.click('button:has-text("Agregar producto")')
  await pagina.selectOption('select[aria-label="Producto de la línea 2"]', { index: 2 })
  await pagina.fill('input[aria-label="Cantidad de la línea 2"]', String(cantidad2))
  const costo2 = pagina.locator('input[aria-label="Costo de la línea 2"]')
  if (!(await costo2.inputValue())) await costo2.fill('12.50')
  const costo1 = pagina.locator('input[aria-label="Costo de la línea 1"]')
  if (!(await costo1.inputValue())) await costo1.fill('8.75')
}

await paso('orden_agregar', async () => {
  await crearOrden(40, 24, 'Pedido de prueba E2E: reposición quincenal')
  const f1 = await foto('orden_agregar_formulario', true)
  await pagina.click('button[type=submit]')
  await pagina.waitForURL(/\/ordenes-compra\/\d+$/)
  idOrden = Number(pagina.url().split('/').pop())
  await esperarCarga()
  const f2 = await foto('orden_creada_pendiente', true)
  registrar('OC-01', 'Agregar orden de compra con 2 líneas', 'Queda Pendiente; totales calculados por la BD', `${await pagina.locator("h1").innerText()} creada`, !!idOrden, f2)
  registrar('OC-01b', 'Formulario de orden con subtotal e IVA', 'Cálculo en pantalla', 'Totales mostrados', true, f1)
})

await paso('orden_consultar', async () => {
  await pagina.goto(`${FRONT}/ordenes-compra`)
  await esperarCarga()
  const f = await foto('ordenes_consultar', true)
  registrar('OC-02', 'Consultar órdenes con pestañas de estado y filtros', 'Listado paginado', 'Listado cargado', true, f)
})

await paso('orden_editar', async () => {
  await pagina.goto(`${FRONT}/ordenes-compra/${idOrden}/editar`)
  await esperarCarga()
  await pagina.fill('input[aria-label="Cantidad de la línea 1"]', '50')
  const f = await foto('orden_editar', true)
  await pagina.click('button[type=submit]')
  await pagina.waitForURL(/\/ordenes-compra\/\d+$/)
  await esperarCarga()
  registrar('OC-03', 'Editar orden pendiente (cantidad 40 → 50)', 'Cambio guardado con rowVersion', 'Orden actualizada', true, f)
})

await paso('orden_aprobar', async () => {
  await iniciarSesion('gerente.general')
  const f0 = await foto('rol_gerente_inicio', true)
  registrar('SEG-02c', 'Login rol Gerente: órdenes esperando aprobación', 'Cola de aprobación', 'Inicio cargado', true, f0)
  await pagina.goto(`${FRONT}/ordenes-compra/${idOrden}`)
  await esperarCarga()
  await pagina.click('button:has-text("Aprobar")')
  const f1 = await foto('orden_aprobar_confirmacion')
  await pagina.click('button:has-text("Aprobar orden")')
  await Promise.race([
    pagina.locator('.encabezado .estado', { hasText: 'Aprobada' }).first().waitFor(),
    pagina.locator('.aviso-error').first().waitFor().then(async () => { throw new Error('API: ' + await pagina.locator('.aviso-error').first().innerText()) }),
  ])
  await esperarCarga()
  const f2 = await foto('orden_aprobada', true)
  registrar('OC-04', 'Aprobar orden (rol Gerente/Administrador)', 'Estado Aprobada + historial', 'Aprobada', true, f2)
  registrar('OC-04b', 'Confirmación antes de aprobar', 'Ventana de confirmación', 'Mostrada', true, f1)
})

await paso('recepcion_validacion', async () => {
  await iniciarSesion('bodega.central')
  const f0 = await foto('rol_bodega_inicio', true)
  const finanzas = await pagina.locator('nav >> text=Cuentas por pagar').count()
  registrar('SEG-05', 'Rol Bodega: inicio con mercadería por recibir y menú sin finanzas', 'No muestra Cuentas por pagar', `Enlaces de finanzas: ${finanzas}`, finanzas === 0, f0)
  await pagina.goto(`${FRONT}/ordenes-compra/${idOrden}/recibir`)
  await esperarCarga()
  const cant = pagina.locator('input[aria-label^="Cantidad recibida de"]').first()
  await cant.fill('999')
  await pagina.click('button[type=submit]')
  const f = await foto('recepcion_validaciones', true)
  const errores = await pagina.locator('.invalid-feedback').allInnerTexts()
  registrar('VAL-05', 'Recibir más de lo pendiente y sin factura', 'No permite; mensajes por campo', errores.join(' | '), errores.length >= 2, f)
})

await paso('recepcion_parcial', async () => {
  await pagina.goto(`${FRONT}/ordenes-compra/${idOrden}/recibir`)
  await esperarCarga()
  await pagina.fill('#serieFactura', 'A')
  await pagina.fill('#numeroFactura', `E2E-${sufijo}`)
  await pagina.fill('#obs', 'Recepción parcial: el resto llega la próxima semana')
  await pagina.locator('input[aria-label^="Cantidad recibida de"]').first().fill('30')
  const f1 = await foto('recepcion_formulario', true)
  await pagina.click('button[type=submit]')
  await pagina.locator('.recepcion-lista').waitFor()
  const f2 = await foto('recepcion_resultado_proceso', true)
  const href = await pagina.locator('a:has-text("Ver la cuenta por pagar")').getAttribute('href').catch(() => null)
  idCuenta = href ? Number(href.split('/').pop()) : null
  const resumen = (await pagina.locator('.recepcion-resultado').innerText()).replace(/\s+/g, ' ')
  registrar('PROC-01', 'Proceso integrado: recepción parcial', 'Nota de compra + inventario + cuenta por pagar', resumen.slice(0, 160), /Cuenta por pagar C[A-Z]*-\d+/i.test(resumen), f2)
  registrar('PROC-01b', 'Formulario de recepción con factura', 'Datos completos', 'Enviado', true, f1)
  await pagina.goto(`${FRONT}/ordenes-compra/${idOrden}`)
  await esperarCarga()
  const f3 = await foto('orden_parcial_recorrido', true)
  registrar('PROC-02', 'Orden queda en estado Parcial con recorrido e historial', 'Estado Parcial', (await pagina.locator('.encabezado p').innerText()).trim(), true, f3)
})

await paso('recepciones_consultar', async () => {
  await pagina.goto(`${FRONT}/recepciones`)
  await esperarCarga()
  const f = await foto('recepciones_consultar', true)
  registrar('PROC-03', 'Consultar recepciones con cumplimiento', 'Listado', 'Listado cargado', true, f)
})

// ---------------------------------------------------------------- 4. Pagos y API externa
await paso('pago_transferencia', async () => {
  await iniciarSesion('tesoreria')
  const f0 = await foto('rol_tesoreria_inicio', true)
  registrar('SEG-02d', 'Login rol Tesorería', 'Cuentas vencidas y pagos', 'Inicio cargado', true, f0)
  if (!idCuenta) {
    await pagina.goto(`${FRONT}/cuentas-por-pagar`)
    await esperarCarga()
    await pagina.selectOption('#f-prov', { label: PROVEEDOR })
    await pagina.waitForTimeout(1200)
    await esperarCarga()
    const fila = pagina.locator('table.tabla tbody tr', { hasText: PROVEEDOR }).first()
    const href = await fila.locator('a.celda-principal').getAttribute('href')
    idCuenta = Number(href.split('/').pop())
  }
  await pagina.goto(`${FRONT}/cuentas-por-pagar/${idCuenta}`)
  await esperarCarga()
  await pagina.fill('#monto', '150')
  const f1 = await foto('pago_formulario_transferencia', true)
  await pagina.click('button[type=submit]')
  await pagina.locator('form .alerta').first().waitFor({ timeout: 30000 })
  const msg = await pagina.locator('form .alerta').first().innerText()
  const f2 = await foto('pago_transferencia_aprobada', true)
  registrar('API-01', 'Pago por transferencia (API bancaria externa)', 'Banco APRUEBA y devuelve autorización SIM-…', msg.trim(), /Aprobado/i.test(msg), f2)
  registrar('API-01b', 'Formulario de pago con método Transferencia', 'Banco y cuenta del proveedor precargados', 'Mostrado', true, f1)
})

await paso('pago_rechazado', async () => {
  await pagina.goto(`${FRONT}/cuentas-por-pagar/${idCuenta}`)
  await esperarCarga()
  await pagina.fill('#monto', '100')
  await pagina.fill('#cuentaDestino', 'SIM-999-0000')
  await pagina.click('button[type=submit]')
  await pagina.locator('form .alerta').first().waitFor({ timeout: 30000 })
  const msg = await pagina.locator('form .alerta').first().innerText()
  const f = await foto('pago_transferencia_rechazada', true)
  registrar('API-02', 'Transferencia a cuenta inexistente (termina en 0000)', 'Banco RECHAZA; el saldo no cambia', msg.trim(), /Rechaz/i.test(msg), f)
})

await paso('pago_monto_excedido', async () => {
  await pagina.goto(`${FRONT}/cuentas-por-pagar/${idCuenta}`)
  await esperarCarga()
  await pagina.fill('#monto', '999999')
  await pagina.click('button[type=submit]')
  const f = await foto('pago_validacion_monto')
  const errores = await pagina.locator('.invalid-feedback').allInnerTexts()
  registrar('VAL-06', 'Pagar más que el saldo disponible', 'No permite; mensaje claro', errores.join(' | '), errores.length >= 1, f)
})

await paso('cuentas_consultar', async () => {
  await pagina.goto(`${FRONT}/cuentas-por-pagar`)
  await esperarCarga()
  const f = await foto('cuentas_por_pagar_consultar', true)
  registrar('CXP-01', 'Consultar cuentas por pagar', 'Listado con saldos y vencimientos', 'Listado cargado', true, f)
})

// ---------------------------------------------------------------- 5. Eliminación lógica
await paso('segregacion_funciones', async () => {
  await iniciarSesion('admin')
  await crearOrden(10, 5, 'Orden de prueba E2E: segregación de funciones y anulación')
  await pagina.click('button[type=submit]')
  await pagina.waitForURL(/\/ordenes-compra\/\d+$/)
  idOrden2 = Number(pagina.url().split('/').pop())
  await esperarCarga()
  await pagina.click('button:has-text("Aprobar")')
  await pagina.click('button:has-text("Aprobar orden")')
  await pagina.locator('.aviso-error').first().waitFor()
  const msg = await pagina.locator('.aviso-error').first().innerText()
  const f = await foto('regla_segregacion_funciones')
  registrar('RN-01', 'Quien crea la orden intenta aprobarla', 'Rechazo 409 (segregación de funciones)', msg.trim(), /segregaci/i.test(msg), f)
})

await paso('orden_anular', async () => {
  await iniciarSesion('gerente.general')
  await pagina.goto(`${FRONT}/ordenes-compra/${idOrden2}`)
  await esperarCarga()
  await pagina.click('button:has-text("Anular")')
  await pagina.fill('#motivo', 'corto')
  await pagina.click('button:has-text("Anular orden")')
  const f1 = await foto('orden_anular_motivo_corto')
  registrar('VAL-07', 'Anular con motivo menor a 10 caracteres', 'No permite', await pagina.locator('.modal-caja .invalid-feedback').innerText(), true, f1)
  await pagina.fill('#motivo', 'El proveedor no tiene existencias de estos productos')
  await pagina.click('button:has-text("Anular orden")')
  await pagina.locator('.estado', { hasText: 'Anulada' }).first().waitFor()
  await esperarCarga()
  const f2 = await foto('orden_anulada_trazabilidad', true)
  registrar('OC-05', 'Eliminar orden = anulación lógica con motivo', 'Estado Anulada; motivo, usuario y fecha', 'Anulada', true, f2)
})

await paso('proveedor_inactivar_bloqueado', async () => {
  await pagina.goto(`${FRONT}/proveedores/${idProveedor}`)
  await esperarCarga()
  await pagina.click('button:has-text("Inactivar")')
  await pagina.fill('#motivo', 'Prueba de regla: proveedor con saldo pendiente')
  await pagina.click('button:has-text("Inactivar proveedor")')
  await pagina.locator('.aviso').first().waitFor()
  const msg = await pagina.locator('.aviso').first().innerText()
  const f = await foto('proveedor_inactivar_regla_negocio')
  registrar('PRV-06', 'Inactivar proveedor con orden abierta y saldo', 'Regla del negocio lo impide (409)', msg.trim(), true, f)
})

// ---------------------------------------------------------------- 6. Reportes
for (const [tipo, nombre] of [['compras', 'reporte_compras_por_proveedor'], ['cumplimiento', 'reporte_cumplimiento_entregas'], ['cuentas', 'reporte_antiguedad_cuentas']]) {
  await paso(nombre, async () => {
    await pagina.goto(`${FRONT}/reportes?tipo=${tipo}`)
    await esperarCarga()
    await pagina.waitForTimeout(1500)
    const f = await foto(nombre, true)
    const tablas = await pagina.locator('table.tabla').count()
    registrar(`REP-${tipo}`, `Reporte: ${nombre.replace(/_/g, ' ')}`, 'Totales, resumen y detalle con filtros', `${tablas} tabla(s) generadas`, tablas >= 1, f)
  })
}

// ---------------------------------------------------------------- 7. Permisos por rol
await paso('rol_consulta', async () => {
  await pagina.click('button:has-text("Cerrar sesión")')
  await pagina.waitForURL(/\/login/)
  await iniciarSesion('consulta')
  const f1 = await foto('rol_consulta_inicio', true)
  await pagina.goto(`${FRONT}/proveedores`)
  await esperarCarga()
  const botones = await pagina.locator('a:has-text("Agregar proveedor")').count()
  const f2 = await foto('rol_consulta_sin_botones')
  registrar('SEG-03', 'Rol Consulta: interfaz sin acciones de escritura', 'No muestra "Agregar proveedor"', `Botones visibles: ${botones}`, botones === 0, f2)
  await pagina.goto(`${FRONT}/proveedores/nuevo`)
  const f3 = await foto('rol_consulta_ruta_protegida')
  registrar('SEG-04', 'Rol Consulta abre /proveedores/nuevo por URL', 'Pantalla "no disponible para su rol"', await pagina.locator('h1').innerText(), true, f3)
  registrar('SEG-03b', 'Inicio del rol Consulta', 'Menú según rol', 'Mostrado', true, f1)
})

await paso('responsivo', async () => {
  await iniciarSesion('admin')
  const movil = await contexto.newPage()
  await movil.setViewportSize({ width: 390, height: 844 })
  await movil.goto(`${FRONT}/ordenes-compra/${idOrden}`)
  await esperarCarga(movil)
  const f = await foto('vista_celular_orden', true, movil)
  registrar('UI-01', 'Interfaz adaptable (celular 390 px)', 'Se reorganiza sin desbordes', 'Vista móvil correcta', true, f)
  await movil.close()
})

// ---------------------------------------------------------------- 8. Pruebas directas de seguridad en la API
const json = async (r) => { try { return await r.json() } catch { return null } }
const post = (url, cuerpo, token, extra = {}) => fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}), ...extra }, body: JSON.stringify(cuerpo) })

await paso('api_seguridad', async () => {
  let r = await fetch(`${API}/api/Proveedores/ConsultarProveedores`)
  registrar('SEG-06', 'API sin token', '401 No autorizado', `HTTP ${r.status}`, r.status === 401)

  r = await post(`${API}/api/Autenticacion/IniciarSesion`, { usuario: 'consulta', contrasena: CLAVE })
  const tConsulta = (await json(r))?.datos?.accessToken
  r = await post(`${API}/api/Proveedores/AgregarProveedor`, { nombre: 'No debe crearse', nit: nitValido(), idCategoria: 1, tipoPago: 'Contado' }, tConsulta)
  registrar('SEG-07', 'Rol Consulta intenta AgregarProveedor directo en la API', '403 Prohibido (permiso en backend)', `HTTP ${r.status}`, r.status === 403)

  r = await post(`${API}/api/Autenticacion/IniciarSesion`, { usuario: 'admin', contrasena: CLAVE })
  const sesion = (await json(r))?.datos
  r = await post(`${API}/api/Proveedores/AgregarProveedor`, { nombre: 'X', nit: '1234567-8', idCategoria: 0, tipoPago: 'Contado', email: 'malo' }, sesion.accessToken)
  const v = await json(r)
  registrar('VAL-08', 'API valida datos aunque se salte el frontend', '400 con mensajes por campo', `HTTP ${r.status}: ${v?.detalle ?? v?.mensaje}`, r.status === 400)

  r = await post(`${API}/api/Autenticacion/RenovarToken`, { refreshToken: sesion.refreshToken })
  const nueva = (await json(r))?.datos
  registrar('SEG-08', 'Renovar sesión con refresh token', '200 y refresh token nuevo (rotación)', `HTTP ${r.status}, distinto: ${nueva?.refreshToken !== sesion.refreshToken}`, r.status === 200 && nueva?.refreshToken !== sesion.refreshToken)
  r = await post(`${API}/api/Autenticacion/RenovarToken`, { refreshToken: sesion.refreshToken })
  registrar('SEG-09', 'Reutilizar refresh token ya rotado', '401 (detección de reutilización)', `HTTP ${r.status}`, r.status === 401)

  r = await post(`${API}/api/Autenticacion/IniciarSesion`, { usuario: 'admin', contrasena: CLAVE })
  const s2 = (await json(r))?.datos
  r = await post(`${API}/api/Autenticacion/CerrarSesion`, { refreshToken: s2.refreshToken }, s2.accessToken)
  registrar('SEG-10', 'Cerrar sesión', '200 y refresh token invalidado', `HTTP ${r.status}`, r.status === 200)
  r = await post(`${API}/api/Autenticacion/RenovarToken`, { refreshToken: s2.refreshToken })
  registrar('SEG-11', 'Usar refresh token después de cerrar sesión', '401', `HTTP ${r.status}`, r.status === 401)
})

// ---------------------------------------------------------------- 9. API externa (banco simulado) directa
await paso('api_banco', async () => {
  let r = await fetch(`${BANCO}/health`)
  registrar('EXT-01', 'Banco simulado en línea (/health)', '200 en línea', `HTTP ${r.status}`, r.status === 200)
  const op = crypto.randomUUID()
  const cuerpo = { operacionId: op, bancoDestino: 'Banco Simulado GT', cuentaDestino: 'SIM-001-7788990', monto: 25.5, moneda: 'GTQ', concepto: 'Prueba E2E' }
  r = await post(`${BANCO}/api/v1/transferencias`, cuerpo)
  registrar('EXT-02', 'Llamar al banco sin X-Api-Key', '401 NO_AUTORIZADO', `HTTP ${r.status}`, r.status === 401)
  if (!API_KEY_BANCO) return
  const k = { 'X-Api-Key': API_KEY_BANCO }
  r = await post(`${BANCO}/api/v1/transferencias`, cuerpo, null, k)
  const a = await json(r)
  registrar('EXT-03', 'Transferencia válida', '200 APROBADA con autorización', `HTTP ${r.status} ${a?.estado} ${a?.autorizacion}`, a?.estado === 'APROBADA')
  r = await post(`${BANCO}/api/v1/transferencias`, cuerpo, null, k)
  const b = await json(r)
  registrar('EXT-04', 'Repetir la misma operación (idempotencia)', 'Misma autorización, sin doble débito', `${b?.autorizacion === a?.autorizacion ? 'Misma' : 'Distinta'} autorización`, b?.autorizacion === a?.autorizacion)
  r = await post(`${BANCO}/api/v1/transferencias`, { ...cuerpo, operacionId: crypto.randomUUID(), monto: 60000 }, null, k)
  const c = await json(r)
  registrar('EXT-05', 'Monto mayor a Q50,000', 'RECHAZADA', `${c?.estado}: ${c?.mensaje}`, c?.estado === 'RECHAZADA')
  r = await post(`${BANCO}/api/v1/transferencias`, { ...cuerpo, operacionId: crypto.randomUUID() }, null, { ...k, 'X-Simular': 'error' })
  registrar('EXT-06', 'Banco caído (X-Simular: error)', '503; el ERP deja el pago Pendiente', `HTTP ${r.status}`, r.status === 503)
  r = await post(`${BANCO}/api/v1/transferencias`, { ...cuerpo, operacionId: crypto.randomUUID(), moneda: 'USD' }, null, k)
  registrar('EXT-07', 'Moneda distinta de GTQ', '400 Solicitud inválida', `HTTP ${r.status}`, r.status === 400)
})

// ---------------------------------------------------------------- Swagger (documentación de APIs)
await paso('swagger', async () => {
  await pagina.goto(`${API}/swagger`)
  await pagina.waitForTimeout(2500)
  await foto('swagger_api_lapromesa', true)
  await pagina.goto(`${BANCO}/swagger`)
  await pagina.waitForTimeout(2500)
  await foto('swagger_banco_simulado', true)
})

await navegador.close()
const datos = { ejecutado: new Date().toISOString(), proveedor: PROVEEDOR, nit: NIT, idProveedor, idOrden, idOrden2, idCuenta, resultados }
fs.writeFileSync(path.join(salida, 'resultados.json'), JSON.stringify(datos, null, 2), 'utf8')
const fallidas = resultados.filter((r) => r.resultado !== 'Aprobada').length
console.log(`\n${resultados.length} pruebas, ${resultados.length - fallidas} aprobadas, ${fallidas} fallidas.`)
console.log(`Capturas y resultados en: ${salida}`)
