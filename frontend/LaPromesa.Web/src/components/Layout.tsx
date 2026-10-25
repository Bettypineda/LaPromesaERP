import { useEffect, useState } from 'react'
import { NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom'
import { useAuth } from '../context/hooks'
import type { Permiso } from '../utils/roles'
import Marca from './Marca'
import './Layout.css'

interface Enlace {
  ruta: string
  texto: string
  icono: string
  permiso?: Permiso
}

interface Grupo {
  titulo: string
  enlaces: Enlace[]
}

const MENU: Grupo[] = [
  { titulo: '', enlaces: [{ ruta: '/', texto: 'Inicio', icono: 'bi-house' }] },
  {
    titulo: 'Compras',
    enlaces: [
      { ruta: '/proveedores', texto: 'Proveedores', icono: 'bi-truck' },
      { ruta: '/ordenes-compra', texto: 'Órdenes de compra', icono: 'bi-receipt' },
      { ruta: '/recepciones', texto: 'Recepciones', icono: 'bi-box-seam' },
    ],
  },
  {
    titulo: 'Finanzas',
    enlaces: [
      { ruta: '/cuentas-por-pagar', texto: 'Cuentas por pagar', icono: 'bi-wallet2', permiso: 'verFinanzas' },
      { ruta: '/pagos-pendientes', texto: 'Pagos en revisión', icono: 'bi-arrow-repeat', permiso: 'registrarPagos' },
    ],
  },
  {
    titulo: 'Análisis',
    enlaces: [{ ruta: '/reportes', texto: 'Reportes', icono: 'bi-bar-chart-line', permiso: 'verReportes' }],
  },
]

function Layout() {
  const { usuario, cerrarSesion, puede } = useAuth()
  const navegar = useNavigate()
  const ubicacion = useLocation()
  const [menuAbierto, setMenuAbierto] = useState(false)

  // En celular, el menú se cierra al cambiar de página
  useEffect(() => {
    setMenuAbierto(false)
  }, [ubicacion.pathname])

  const salir = async () => {
    await cerrarSesion()
    navegar('/login', { replace: true })
  }

  const iniciales = (usuario?.nombreCompleto ?? usuario?.usuario ?? '?')
    .split(' ').filter(Boolean).slice(0, 2).map((p) => p[0]).join('').toUpperCase()

  return (
    <div className={`app ${menuAbierto ? 'menu-abierto' : ''}`}>
      <aside className="lateral" aria-label="Menú principal">
        <div className="lateral-marca">
          <Marca />
        </div>
        <nav className="lateral-nav">
          {MENU.map((grupo) => {
            const visibles = grupo.enlaces.filter((e) => !e.permiso || puede(e.permiso))
            if (visibles.length === 0) return null
            return (
              <div key={grupo.titulo || 'inicio'} className="lateral-grupo">
                {grupo.titulo && <p className="lateral-grupo-titulo">{grupo.titulo}</p>}
                {visibles.map((e) => (
                  <NavLink key={e.ruta} to={e.ruta} end={e.ruta === '/'} className="lateral-enlace">
                    <i className={`bi ${e.icono}`} aria-hidden="true" />
                    <span>{e.texto}</span>
                  </NavLink>
                ))}
              </div>
            )
          })}
        </nav>
        <div className="lateral-pie">
          <div className="usuario">
            <span className="usuario-avatar" aria-hidden="true">{iniciales}</span>
            <span className="usuario-datos">
              <strong>{usuario?.nombreCompleto || usuario?.usuario}</strong>
              <small>{usuario?.rol}</small>
            </span>
          </div>
          <button type="button" className="lateral-salir" onClick={salir}>
            <i className="bi bi-box-arrow-left" aria-hidden="true" /> Cerrar sesión
          </button>
        </div>
      </aside>

      <div className="velo" onClick={() => setMenuAbierto(false)} aria-hidden="true" />

      <div className="principal">
        <header className="barra-movil">
          <button type="button" className="btn-icono" aria-label="Abrir menú" onClick={() => setMenuAbierto(true)}>
            <i className="bi bi-list" aria-hidden="true" />
          </button>
          <Marca compacta />
        </header>
        <main className="contenido" id="contenido">
          <Outlet />
        </main>
      </div>
    </div>
  )
}

export default Layout
