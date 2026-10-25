import { BrowserRouter, Route, Routes } from 'react-router-dom'
import { AuthProvider } from './context/AuthContext'
import { AvisosProvider } from './context/AvisosContext'
import Layout from './components/Layout'
import RutaProtegida from './components/RutaProtegida'
import LoginPage from './pages/LoginPage'
import InicioPage from './pages/InicioPage'
import ProveedoresPage from './pages/ProveedoresPage'
import ProveedorFormPage from './pages/ProveedorFormPage'
import ProveedorDetallePage from './pages/ProveedorDetallePage'
import OrdenesCompraPage from './pages/OrdenesCompraPage'
import OrdenCompraFormPage from './pages/OrdenCompraFormPage'
import OrdenCompraDetallePage from './pages/OrdenCompraDetallePage'
import RecibirOrdenPage from './pages/RecibirOrdenPage'
import RecepcionesPage from './pages/RecepcionesPage'
import RecepcionDetallePage from './pages/RecepcionDetallePage'
import CuentasPorPagarPage from './pages/CuentasPorPagarPage'
import CuentaPorPagarDetallePage from './pages/CuentaPorPagarDetallePage'
import PagosPendientesPage from './pages/PagosPendientesPage'
import ReportesPage from './pages/ReportesPage'
import NoEncontradaPage from './pages/NoEncontradaPage'

function App() {
  return (
    <BrowserRouter>
      <AvisosProvider>
        <AuthProvider>
          <Routes>
            <Route path="/login" element={<LoginPage />} />

            <Route element={<RutaProtegida />}>
              <Route element={<Layout />}>
                <Route index element={<InicioPage />} />

                {/* Proveedores (CRUD) */}
                <Route path="proveedores" element={<ProveedoresPage />} />
                <Route path="proveedores/:id" element={<ProveedorDetallePage />} />
                <Route element={<RutaProtegida permiso="gestionarProveedores" />}>
                  <Route path="proveedores/nuevo" element={<ProveedorFormPage />} />
                  <Route path="proveedores/:id/editar" element={<ProveedorFormPage />} />
                </Route>

                {/* Órdenes de compra (CRUD) + proceso integrado */}
                <Route path="ordenes-compra" element={<OrdenesCompraPage />} />
                <Route path="ordenes-compra/:id" element={<OrdenCompraDetallePage />} />
                <Route element={<RutaProtegida permiso="crearCompras" />}>
                  <Route path="ordenes-compra/nueva" element={<OrdenCompraFormPage />} />
                  <Route path="ordenes-compra/:id/editar" element={<OrdenCompraFormPage />} />
                </Route>
                <Route element={<RutaProtegida permiso="recibirMercaderia" />}>
                  <Route path="ordenes-compra/:id/recibir" element={<RecibirOrdenPage />} />
                </Route>
                <Route path="recepciones" element={<RecepcionesPage />} />
                <Route path="recepciones/:id" element={<RecepcionDetallePage />} />

                {/* Cuentas por pagar y pagos (API bancaria) */}
                <Route element={<RutaProtegida permiso="verFinanzas" />}>
                  <Route path="cuentas-por-pagar" element={<CuentasPorPagarPage />} />
                  <Route path="cuentas-por-pagar/:id" element={<CuentaPorPagarDetallePage />} />
                </Route>
                <Route element={<RutaProtegida permiso="registrarPagos" />}>
                  <Route path="pagos-pendientes" element={<PagosPendientesPage />} />
                </Route>

                {/* Reportes */}
                <Route element={<RutaProtegida permiso="verReportes" />}>
                  <Route path="reportes" element={<ReportesPage />} />
                </Route>

                <Route path="*" element={<NoEncontradaPage />} />
              </Route>
            </Route>
          </Routes>
        </AuthProvider>
      </AvisosProvider>
    </BrowserRouter>
  )
}

export default App
