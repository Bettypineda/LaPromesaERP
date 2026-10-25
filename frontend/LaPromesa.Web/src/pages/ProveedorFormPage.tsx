import { useEffect, useState, type ChangeEvent, type FormEvent } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { useAvisos } from '../context/hooks'
import { agregarProveedor, buscarProveedor, editarProveedor } from '../services/proveedorService'
import { agregarCategoria, consultarCategorias } from '../services/catalogoService'
import type { ProveedorAgregar } from '../interfaces/Proveedor'
import type { CategoriaConsulta } from '../interfaces/Catalogos'
import { correoValido, nitValido, telefonoValido, type Errores } from '../utils/validaciones'
import { leerError } from '../utils/errores'
import { BANCOS, DEPARTAMENTOS } from '../utils/catalogosFijos'
import EncabezadoPagina from '../components/EncabezadoPagina'
import Campo from '../components/Campo'
import Modal from '../components/Modal'
import { Cargando, MensajeError } from '../components/Estados'
import './Formularios.css'

const VACIO: ProveedorAgregar = {
  nombre: '', nit: '', idCategoria: 0, contacto: '', telefono: '', email: '', direccion: '', departamento: '',
  tipoPago: 'Contado', diasCredito: 0, limiteCredito: 0, banco: '', numeroCuenta: '',
}

// Mismas reglas que ProveedorAgregarDTO (backend) y los CHECK de compras.Proveedores (base de datos)
const validar = (p: ProveedorAgregar): Errores => {
  const e: Errores = {}
  if (p.nombre.trim().length < 3) e.nombre = 'Escriba el nombre o razón social (mínimo 3 caracteres).'
  if (!p.nit.trim()) e.nit = 'El NIT es obligatorio.'
  else if (!nitValido(p.nit)) e.nit = 'El NIT no es válido: revise el dígito verificador (ej. 1234567-9).'
  if (!p.idCategoria) e.idCategoria = 'Seleccione una categoría.'
  if (p.telefono.trim() && !telefonoValido(p.telefono)) e.telefono = 'Use 8 dígitos que inicien con 2 a 7 (ej. 2360-1111).'
  if (p.email.trim() && !correoValido(p.email)) e.email = 'Escriba un correo válido (ej. ventas@empresa.com).'
  if (p.tipoPago === 'Credito') {
    if (!Number.isInteger(p.diasCredito) || p.diasCredito < 1 || p.diasCredito > 180) e.diasCredito = 'Entre 1 y 180 días.'
    if (p.limiteCredito < 0) e.limiteCredito = 'El límite no puede ser negativo.'
  }
  if (!!p.banco.trim() !== !!p.numeroCuenta.trim()) {
    if (!p.banco.trim()) e.banco = 'Indique el banco de la cuenta.'
    else e.numeroCuenta = 'Indique el número de cuenta.'
  }
  return e
}

function ProveedorFormPage() {
  const { id } = useParams()
  const edicion = !!id
  const navegar = useNavigate()
  const { avisar } = useAvisos()

  const [proveedor, setProveedor] = useState<ProveedorAgregar>(VACIO)
  const [rowVersion, setRowVersion] = useState<string | null>(null)
  const [codigo, setCodigo] = useState('')
  const [categorias, setCategorias] = useState<CategoriaConsulta[]>([])
  const [errores, setErrores] = useState<Errores>({})
  const [intento, setIntento] = useState(false)
  const [mensaje, setMensaje] = useState('')
  const [cargando, setCargando] = useState(edicion)
  const [guardando, setGuardando] = useState(false)
  const [modalCategoria, setModalCategoria] = useState(false)

  const cargarCategorias = () =>
    consultarCategorias(true).then((r) => r.exito && setCategorias(r.datos)).catch(() => undefined)

  useEffect(() => { cargarCategorias() }, [])

  useEffect(() => {
    if (!edicion) return
    buscarProveedor(Number(id))
      .then((r) => {
        if (!r.exito) { setMensaje(r.mensaje); return }
        const p = r.datos.proveedor
        setCodigo(p.codigo)
        setRowVersion(p.rowVersion)
        setProveedor({
          nombre: p.nombre, nit: p.nit, idCategoria: p.idCategoria, contacto: p.contacto ?? '', telefono: p.telefono ?? '',
          email: p.email ?? '', direccion: p.direccion ?? '', departamento: p.departamento ?? '', tipoPago: p.tipoPago,
          diasCredito: p.diasCredito, limiteCredito: p.limiteCredito, banco: p.banco ?? '', numeroCuenta: p.numeroCuenta ?? '',
        })
      })
      .catch((e) => setMensaje(leerError(e).mensaje))
      .finally(() => setCargando(false))
  }, [edicion, id])

  const actualizar = (cambios: Partial<ProveedorAgregar>) => {
    const nuevo = { ...proveedor, ...cambios }
    setProveedor(nuevo)
    if (intento) setErrores(validar(nuevo))
  }

  const manejarCambio = (e: ChangeEvent<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target
    const numericos = ['idCategoria', 'diasCredito', 'limiteCredito']
    actualizar({ [name]: numericos.includes(name) ? (value === '' ? 0 : Number(value)) : value } as Partial<ProveedorAgregar>)
  }

  const cambiarTipoPago = (tipoPago: 'Contado' | 'Credito') =>
    actualizar(tipoPago === 'Contado'
      ? { tipoPago, diasCredito: 0, limiteCredito: 0 }
      : { tipoPago, diasCredito: proveedor.diasCredito || 30 })

  const guardar = async (evento: FormEvent) => {
    evento.preventDefault()
    setIntento(true)
    setMensaje('')
    const encontrados = validar(proveedor)
    setErrores(encontrados)
    if (Object.keys(encontrados).length) {
      document.getElementById(Object.keys(encontrados)[0])?.focus()
      return
    }
    setGuardando(true)
    try {
      const datos = { ...proveedor, nombre: proveedor.nombre.trim(), nit: proveedor.nit.trim().toUpperCase() }
      const r = edicion
        ? await editarProveedor({ ...datos, idProveedor: Number(id), rowVersion })
        : await agregarProveedor(datos)
      if (r.exito) {
        avisar(edicion ? 'Cambios guardados.' : `Proveedor ${r.datos.codigo} agregado.`)
        navegar(`/proveedores/${r.datos.idProveedor}`)
      } else {
        setMensaje(r.mensaje)
      }
    } catch (e) {
      const { mensaje: texto, campos } = leerError(e)
      setMensaje(texto)
      setErrores(campos)
    } finally {
      setGuardando(false)
    }
  }

  const clase = (campo: string) => (errores[campo] ? 'is-invalid' : '')

  if (cargando) return <Cargando texto="Cargando proveedor…" />

  return (
    <>
      <EncabezadoPagina
        titulo={edicion ? `Editar proveedor ${codigo}` : 'Agregar proveedor'}
        descripcion={edicion ? proveedor.nombre : 'El código PR### se asigna automáticamente al guardar.'}
        volver={{ ruta: edicion ? `/proveedores/${id}` : '/proveedores', texto: edicion ? 'Detalle del proveedor' : 'Proveedores' }}
      />

      {mensaje && <MensajeError texto={mensaje} />}

      <form className="formulario" onSubmit={guardar} noValidate>
        <section className="panel">
          <div className="panel-cabecera"><h2>Datos generales</h2></div>
          <div className="panel-cuerpo rejilla-campos">
            <Campo id="nombre" etiqueta="Nombre o razón social" requerido error={errores.nombre} className="campo-doble">
              <input id="nombre" name="nombre" className={`form-control ${clase('nombre')}`} maxLength={150}
                value={proveedor.nombre} onChange={manejarCambio} />
            </Campo>
            <Campo id="nit" etiqueta="NIT" requerido error={errores.nit} ayuda="Con dígito verificador, ej. 1234567-9">
              <input id="nit" name="nit" className={`form-control ${clase('nit')}`} maxLength={15}
                value={proveedor.nit} onChange={manejarCambio}
                onBlur={() => {
                  if (proveedor.nit && !nitValido(proveedor.nit)) setErrores((e) => ({ ...e, nit: 'El NIT no es válido: revise el dígito verificador.' }))
                }} />
            </Campo>
            <Campo id="idCategoria" etiqueta="Categoría" requerido error={errores.idCategoria}
              ayuda={<button type="button" className="btn-texto p-0" onClick={() => setModalCategoria(true)}>Crear otra categoría</button>}>
              <select id="idCategoria" name="idCategoria" className={`form-select ${clase('idCategoria')}`}
                value={proveedor.idCategoria || ''} onChange={manejarCambio}>
                <option value="">Seleccione…</option>
                {categorias.map((c) => <option key={c.idCategoria} value={c.idCategoria}>{c.nombre}</option>)}
              </select>
            </Campo>
            <Campo id="departamento" etiqueta="Departamento" error={errores.departamento}>
              <select id="departamento" name="departamento" className="form-select" value={proveedor.departamento} onChange={manejarCambio}>
                <option value="">Sin especificar</option>
                {DEPARTAMENTOS.map((d) => <option key={d}>{d}</option>)}
              </select>
            </Campo>
            <Campo id="direccion" etiqueta="Dirección" error={errores.direccion} className="campo-doble">
              <input id="direccion" name="direccion" className={`form-control ${clase('direccion')}`} maxLength={200}
                value={proveedor.direccion} onChange={manejarCambio} />
            </Campo>
          </div>
        </section>

        <section className="panel">
          <div className="panel-cabecera"><h2>Contacto</h2></div>
          <div className="panel-cuerpo rejilla-campos">
            <Campo id="contacto" etiqueta="Persona de contacto" error={errores.contacto}>
              <input id="contacto" name="contacto" className={`form-control ${clase('contacto')}`} maxLength={100}
                value={proveedor.contacto} onChange={manejarCambio} />
            </Campo>
            <Campo id="telefono" etiqueta="Teléfono" error={errores.telefono} ayuda="8 dígitos, ej. 2360-1111">
              <input id="telefono" name="telefono" type="tel" className={`form-control ${clase('telefono')}`} maxLength={20}
                value={proveedor.telefono} onChange={manejarCambio} />
            </Campo>
            <Campo id="email" etiqueta="Correo electrónico" error={errores.email}>
              <input id="email" name="email" type="email" className={`form-control ${clase('email')}`} maxLength={150}
                value={proveedor.email} onChange={manejarCambio} />
            </Campo>
          </div>
        </section>

        <section className="panel">
          <div className="panel-cabecera"><h2>Condiciones de pago</h2></div>
          <div className="panel-cuerpo">
            <div className="opciones-pago" role="radiogroup" aria-label="Tipo de pago">
              {(['Contado', 'Credito'] as const).map((t) => (
                <label key={t} className={`opcion ${proveedor.tipoPago === t ? 'seleccionada' : ''}`}>
                  <input type="radio" name="tipoPago" value={t} checked={proveedor.tipoPago === t} onChange={() => cambiarTipoPago(t)} />
                  <span>
                    <strong>{t === 'Contado' ? 'Contado' : 'Crédito'}</strong>
                    <small>{t === 'Contado' ? 'La cuenta por pagar vence el día de la recepción.' : 'La cuenta vence después de los días de crédito.'}</small>
                  </span>
                </label>
              ))}
            </div>
            {proveedor.tipoPago === 'Credito' && (
              <div className="rejilla-campos mt-3">
                <Campo id="diasCredito" etiqueta="Días de crédito" requerido error={errores.diasCredito} ayuda="Entre 1 y 180">
                  <input id="diasCredito" name="diasCredito" type="number" min={1} max={180} step={1}
                    className={`form-control ${clase('diasCredito')}`} value={proveedor.diasCredito || ''} onChange={manejarCambio} />
                </Campo>
                <Campo id="limiteCredito" etiqueta="Límite de crédito (Q)" error={errores.limiteCredito} ayuda="0 = sin límite">
                  <input id="limiteCredito" name="limiteCredito" type="number" min={0} step="0.01"
                    className={`form-control ${clase('limiteCredito')}`} value={proveedor.limiteCredito || ''} onChange={manejarCambio} />
                </Campo>
              </div>
            )}
          </div>
        </section>

        <section className="panel">
          <div className="panel-cabecera">
            <h2>Datos bancarios</h2>
            <span className="texto-suave small">Se usan para pagar por transferencia</span>
          </div>
          <div className="panel-cuerpo rejilla-campos">
            <Campo id="banco" etiqueta="Banco" error={errores.banco}>
              <input id="banco" name="banco" list="lista-bancos" className={`form-control ${clase('banco')}`} maxLength={60}
                value={proveedor.banco} onChange={manejarCambio} />
              <datalist id="lista-bancos">{BANCOS.map((b) => <option key={b} value={b} />)}</datalist>
            </Campo>
            <Campo id="numeroCuenta" etiqueta="Número de cuenta" error={errores.numeroCuenta}>
              <input id="numeroCuenta" name="numeroCuenta" className={`form-control ${clase('numeroCuenta')}`} maxLength={30}
                value={proveedor.numeroCuenta} onChange={manejarCambio} />
            </Campo>
          </div>
        </section>

        <div className="formulario-acciones">
          <Link to={edicion ? `/proveedores/${id}` : '/proveedores'} className="btn btn-claro">Cancelar</Link>
          <button type="submit" className="btn btn-primary" disabled={guardando}>
            {guardando ? <><span className="spinner-border spinner-border-sm" /> Guardando…</> : edicion ? 'Guardar cambios' : 'Agregar proveedor'}
          </button>
        </div>
      </form>

      <ModalCategoria abierto={modalCategoria} onCerrar={() => setModalCategoria(false)}
        onCreada={(c) => { cargarCategorias(); actualizar({ idCategoria: c.idCategoria }); setModalCategoria(false) }} />
    </>
  )
}

function ModalCategoria({ abierto, onCerrar, onCreada }: {
  abierto: boolean; onCerrar: () => void; onCreada: (c: CategoriaConsulta) => void
}) {
  const { avisar } = useAvisos()
  const [nombre, setNombre] = useState('')
  const [descripcion, setDescripcion] = useState('')
  const [error, setError] = useState('')
  const [guardando, setGuardando] = useState(false)

  const guardar = async () => {
    if (nombre.trim().length < 3) { setError('Escriba el nombre (mínimo 3 caracteres).'); return }
    setGuardando(true)
    try {
      const r = await agregarCategoria({ nombre: nombre.trim(), descripcion: descripcion.trim() })
      if (r.exito) {
        avisar(`Categoría ${r.datos.nombre} creada.`)
        setNombre(''); setDescripcion(''); setError('')
        onCreada(r.datos)
      } else setError(r.mensaje)
    } catch (e) {
      setError(leerError(e).mensaje)
    } finally {
      setGuardando(false)
    }
  }

  return (
    <Modal abierto={abierto} titulo="Nueva categoría de proveedor" onCerrar={onCerrar}
      pie={<>
        <button type="button" className="btn btn-claro" onClick={onCerrar}>Cancelar</button>
        <button type="button" className="btn btn-primary" onClick={guardar} disabled={guardando}>{guardando ? 'Creando…' : 'Crear categoría'}</button>
      </>}>
      <Campo id="cat-nombre" etiqueta="Nombre" requerido error={error}>
        <input id="cat-nombre" className={`form-control ${error ? 'is-invalid' : ''}`} maxLength={50} value={nombre} onChange={(e) => setNombre(e.target.value)} />
      </Campo>
      <Campo id="cat-desc" etiqueta="Descripción">
        <textarea id="cat-desc" className="form-control" rows={2} maxLength={200} value={descripcion} onChange={(e) => setDescripcion(e.target.value)} />
      </Campo>
    </Modal>
  )
}

export default ProveedorFormPage
