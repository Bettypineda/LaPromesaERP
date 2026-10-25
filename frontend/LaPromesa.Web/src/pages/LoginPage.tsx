import { useState, type FormEvent } from 'react'
import { Navigate, useLocation, useNavigate } from 'react-router-dom'
import { useAuth } from '../context/hooks'
import { leerError } from '../utils/errores'
import Marca from '../components/Marca'
import './LoginPage.css'

const PASOS = [
  { icono: 'bi-truck', texto: 'Proveedor registrado y validado' },
  { icono: 'bi-receipt', texto: 'Orden de compra aprobada' },
  { icono: 'bi-box-seam', texto: 'Mercadería recibida en bodega' },
  { icono: 'bi-bank', texto: 'Pago confirmado por el banco' },
]

const USUARIOS_DEMO = ['admin', 'sara.compras', 'gerente.general', 'bodega.central', 'tesoreria', 'consulta']

function LoginPage() {
  const { usuario, iniciarSesion, sesionExpirada } = useAuth()
  const navegar = useNavigate()
  const ubicacion = useLocation()
  const destino = (ubicacion.state as { desde?: string } | null)?.desde ?? '/'

  const [datos, setDatos] = useState({ usuario: '', contrasena: '' })
  const [errores, setErrores] = useState<Record<string, string>>({})
  const [mensaje, setMensaje] = useState('')
  const [enviando, setEnviando] = useState(false)
  const [verContrasena, setVerContrasena] = useState(false)

  if (usuario) return <Navigate to={destino} replace />

  const validar = () => {
    const e: Record<string, string> = {}
    if (datos.usuario.trim().length < 3) e.usuario = 'Escriba su usuario (mínimo 3 caracteres).'
    if (datos.contrasena.length < 6) e.contrasena = 'Escriba su contraseña (mínimo 6 caracteres).'
    setErrores(e)
    return Object.keys(e).length === 0
  }

  const ingresar = async (evento: FormEvent) => {
    evento.preventDefault()
    setMensaje('')
    if (!validar()) return
    setEnviando(true)
    try {
      await iniciarSesion(datos.usuario.trim(), datos.contrasena)
      navegar(destino, { replace: true })
    } catch (error) {
      const { mensaje: texto, campos } = leerError(error, 'Usuario o contraseña incorrectos.')
      setErrores(campos)
      setMensaje(error instanceof Error && !('isAxiosError' in error) ? error.message : texto)
    } finally {
      setEnviando(false)
    }
  }

  return (
    <div className="login">
      <section className="login-relato" aria-hidden="true">
        <Marca />
        <div className="login-relato-cuerpo">
          <h2>Cada compra, de la orden al pago.</h2>
          <ol className="login-pasos">
            {PASOS.map((p) => (
              <li key={p.texto}>
                <span className="login-paso-icono"><i className={`bi ${p.icono}`} /></span>
                <span>{p.texto}</span>
              </li>
            ))}
          </ol>
        </div>
        <p className="login-relato-pie">Proyecto final de Desarrollo Web, UMG Cuilapa</p>
      </section>

      <section className="login-formulario">
        <form className="login-caja" onSubmit={ingresar} noValidate>
          <div className="login-marca-movil"><Marca clara={false} /></div>
          <h1>Iniciar sesión</h1>
          <p className="texto-suave">Ingrese con el usuario que le asignó el administrador.</p>

          {sesionExpirada && !mensaje && (
            <div className="alerta alerta-alerta"><i className="bi bi-clock-history" /><span>Su sesión venció. Ingrese de nuevo para continuar.</span></div>
          )}
          {mensaje && (
            <div className="alerta alerta-error" role="alert"><i className="bi bi-exclamation-triangle" /><span>{mensaje}</span></div>
          )}

          <div className="campo">
            <label htmlFor="usuario" className="form-label">Usuario</label>
            <input id="usuario" className={`form-control form-control-lg ${errores.usuario ? 'is-invalid' : ''}`}
              autoComplete="username" autoFocus maxLength={50} value={datos.usuario}
              onChange={(e) => setDatos({ ...datos, usuario: e.target.value })} />
            {errores.usuario && <div className="invalid-feedback">{errores.usuario}</div>}
          </div>

          <div className="campo">
            <label htmlFor="contrasena" className="form-label">Contraseña</label>
            <div className="input-group has-validation">
              <input id="contrasena" type={verContrasena ? 'text' : 'password'}
                className={`form-control form-control-lg ${errores.contrasena ? 'is-invalid' : ''}`}
                autoComplete="current-password" maxLength={100} value={datos.contrasena}
                onChange={(e) => setDatos({ ...datos, contrasena: e.target.value })} />
              <button type="button" className="btn btn-claro" onClick={() => setVerContrasena(!verContrasena)}
                aria-label={verContrasena ? 'Ocultar contraseña' : 'Mostrar contraseña'}>
                <i className={`bi ${verContrasena ? 'bi-eye-slash' : 'bi-eye'}`} />
              </button>
              {errores.contrasena && <div className="invalid-feedback">{errores.contrasena}</div>}
            </div>
          </div>

          <button type="submit" className="btn btn-primary btn-lg w-100" disabled={enviando}>
            {enviando ? <><span className="spinner-border spinner-border-sm" /> Verificando…</> : 'Ingresar'}
          </button>

          <p className="login-nota">
            Después de 5 intentos fallidos el usuario se bloquea por 15 minutos.
          </p>

          {import.meta.env.DEV && (
            <details className="login-demo">
              <summary>Usuarios de prueba (ambiente local)</summary>
              <div className="login-demo-lista">
                {USUARIOS_DEMO.map((u) => (
                  <button key={u} type="button" className="btn btn-claro btn-sm" onClick={() => setDatos({ ...datos, usuario: u })}>{u}</button>
                ))}
              </div>
              <small>La contraseña es la configurada en Seed:PasswordDemo del backend.</small>
            </details>
          )}
        </form>
      </section>
    </div>
  )
}

export default LoginPage
