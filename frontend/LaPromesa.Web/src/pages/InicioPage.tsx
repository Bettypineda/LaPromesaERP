import { useCallback, useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { useAuth } from '../context/hooks'
import { consultarProveedores } from '../services/proveedorService'
import { consultarOrdenesCompra } from '../services/ordenCompraService'
import { consultarCuentasPorPagar, consultarPagosPendientes } from '../services/cuentaPorPagarService'
import type { OrdenCompraConsulta } from '../interfaces/OrdenCompra'
import type { CuentaPorPagarConsulta } from '../interfaces/CuentaPorPagar'
import { formatoFecha, formatoMoneda } from '../utils/formato'
import { DESCRIPCION_ROL } from '../utils/roles'
import EstadoBadge from '../components/EstadoBadge'
import { Cargando, SinRegistros } from '../components/Estados'
import './InicioPage.css'

interface Resumen {
  proveedoresActivos: number | null
  porAprobar: OrdenCompraConsulta[]
  totalPorAprobar: number | null
  porRecibir: OrdenCompraConsulta[]
  totalPorRecibir: number | null
  atrasadas: number | null
  cuentasVencidas: CuentaPorPagarConsulta[]
  totalVencidas: number | null
  pagosEnRevision: number | null
}

const saludo = () => {
  const h = new Date().getHours()
  return h < 12 ? 'Buenos días' : h < 19 ? 'Buenas tardes' : 'Buenas noches'
}

function InicioPage() {
  const { usuario, puede } = useAuth()
  const [resumen, setResumen] = useState<Resumen | null>(null)

  const cargar = useCallback(async () => {
    const valor = <T,>(r: PromiseSettledResult<T>) => (r.status === 'fulfilled' ? r.value : null)
    const [prov, pend, aprob, parc, atras, venc, pagos] = await Promise.allSettled([
      consultarProveedores({ estado: 'Activo', pagina: 1, tamanoPagina: 1 }),
      consultarOrdenesCompra({ estado: 'Pendiente', ordenarPor: 'FechaOrden', direccion: 'ASC', pagina: 1, tamanoPagina: 5 }),
      consultarOrdenesCompra({ estado: 'Aprobada', ordenarPor: 'FechaEsperada', direccion: 'ASC', pagina: 1, tamanoPagina: 5 }),
      consultarOrdenesCompra({ estado: 'Parcial', ordenarPor: 'FechaEsperada', direccion: 'ASC', pagina: 1, tamanoPagina: 5 }),
      consultarOrdenesCompra({ soloAtrasadas: true, pagina: 1, tamanoPagina: 1 }),
      puede('verFinanzas') ? consultarCuentasPorPagar({ soloVencidas: true, pagina: 1, tamanoPagina: 5 }) : Promise.reject(),
      puede('registrarPagos') ? consultarPagosPendientes() : Promise.reject(),
    ])
    const aprobadas = valor(aprob)?.datos
    const parciales = valor(parc)?.datos
    const porRecibir = [...(parciales?.registros ?? []), ...(aprobadas?.registros ?? [])]
      .sort((a, b) => a.fechaEsperada.localeCompare(b.fechaEsperada)).slice(0, 5)
    setResumen({
      proveedoresActivos: valor(prov)?.datos.total ?? null,
      porAprobar: valor(pend)?.datos.registros ?? [],
      totalPorAprobar: valor(pend)?.datos.total ?? null,
      porRecibir,
      totalPorRecibir: aprobadas || parciales ? (aprobadas?.total ?? 0) + (parciales?.total ?? 0) : null,
      atrasadas: valor(atras)?.datos.total ?? null,
      cuentasVencidas: valor(venc)?.datos.registros ?? [],
      totalVencidas: valor(venc)?.datos.total ?? null,
      pagosEnRevision: valor(pagos)?.datos.length ?? null,
    })
  }, [puede])

  useEffect(() => { cargar() }, [cargar])

  const nombre = usuario?.nombreCompleto?.split(' ')[0] || usuario?.usuario

  return (
    <div className="inicio">
      <header className="inicio-saludo">
        <div>
          <h1>{saludo()}, {nombre}</h1>
          <p>Ingresó como <strong>{usuario?.rol}</strong>: {DESCRIPCION_ROL[usuario?.rol ?? '']?.toLowerCase()}.</p>
        </div>
        <div className="encabezado-acciones">
          {puede('crearCompras') && <Link to="/ordenes-compra/nueva" className="btn btn-acento"><i className="bi bi-plus-lg" /> Nueva orden de compra</Link>}
          {puede('gestionarProveedores') && <Link to="/proveedores/nuevo" className="btn btn-claro"><i className="bi bi-person-plus" /> Nuevo proveedor</Link>}
        </div>
      </header>

      {!resumen ? <Cargando texto="Preparando su resumen…" /> : (
        <>
          <div className="cifras">
            <Link to="/proveedores" className="cifra cifra-enlace">
              <span className="cifra-valor">{resumen.proveedoresActivos ?? '—'}</span>
              <span className="cifra-etiqueta">Proveedores activos</span>
            </Link>
            <Link to="/ordenes-compra?estado=Pendiente" className="cifra cifra-enlace">
              <span className="cifra-valor">{resumen.totalPorAprobar ?? '—'}</span>
              <span className="cifra-etiqueta">Órdenes por aprobar</span>
            </Link>
            <Link to="/ordenes-compra?soloAtrasadas=true" className={`cifra cifra-enlace ${resumen.atrasadas ? 'cifra-alerta' : ''}`}>
              <span className="cifra-valor">{resumen.atrasadas ?? '—'}</span>
              <span className="cifra-etiqueta">Entregas atrasadas</span>
            </Link>
            {resumen.totalVencidas !== null ? (
              <Link to="/cuentas-por-pagar?soloVencidas=true" className={`cifra cifra-enlace ${resumen.totalVencidas ? 'cifra-alerta' : ''}`}>
                <span className="cifra-valor">{resumen.totalVencidas}</span>
                <span className="cifra-etiqueta">Cuentas vencidas</span>
              </Link>
            ) : (
              <Link to="/recepciones" className="cifra cifra-enlace">
                <span className="cifra-valor">{resumen.totalPorRecibir ?? '—'}</span>
                <span className="cifra-etiqueta">Órdenes por recibir</span>
              </Link>
            )}
          </div>

          {resumen.pagosEnRevision ? (
            <div className="alerta alerta-alerta">
              <i className="bi bi-hourglass-split" />
              <span>Hay {resumen.pagosEnRevision} pago(s) por transferencia sin confirmar por el banco.</span>
              <Link to="/pagos-pendientes" className="btn btn-claro btn-sm">Revisar</Link>
            </div>
          ) : null}

          <div className="inicio-colas">
            {(puede('autorizarCompras') || usuario?.rol === 'Compras') && (
              <section className="panel">
                <div className="panel-cabecera">
                  <h2>Órdenes esperando aprobación</h2>
                  <Link to="/ordenes-compra?estado=Pendiente" className="btn-texto">Ver todas</Link>
                </div>
                <ListaOrdenes ordenes={resumen.porAprobar} vacio="No hay órdenes pendientes de aprobar." accion={puede('autorizarCompras') ? 'Revisar y aprobar' : undefined} />
              </section>
            )}

            <section className="panel">
              <div className="panel-cabecera">
                <h2>Mercadería por recibir</h2>
                <Link to="/ordenes-compra?estado=Aprobada" className="btn-texto">Ver todas</Link>
              </div>
              <ListaOrdenes ordenes={resumen.porRecibir} vacio="No hay órdenes aprobadas pendientes de recepción." recibir={puede('recibirMercaderia')} />
            </section>

            {puede('verFinanzas') && (
              <section className="panel">
                <div className="panel-cabecera">
                  <h2>Cuentas vencidas</h2>
                  <Link to="/cuentas-por-pagar?soloVencidas=true" className="btn-texto">Ver todas</Link>
                </div>
                {resumen.cuentasVencidas.length === 0
                  ? <SinRegistros icono="bi-check2-circle" titulo="Ninguna cuenta vencida" />
                  : (
                    <ul className="cola">
                      {resumen.cuentasVencidas.map((c) => (
                        <li key={c.idCuentaPagar}>
                          <Link to={`/cuentas-por-pagar/${c.idCuentaPagar}`} className="cola-item">
                            <span className="cola-principal">
                              <strong>{c.proveedor}</strong>
                              <small>{c.numero} · factura {c.facturaProveedor}</small>
                            </span>
                            <span className="cola-dato">
                              <strong className="numero">{formatoMoneda(c.saldo)}</strong>
                              <small className="texto-error">{c.diasVencida} días vencida</small>
                            </span>
                          </Link>
                        </li>
                      ))}
                    </ul>
                  )}
              </section>
            )}
          </div>
        </>
      )}
    </div>
  )
}

function ListaOrdenes({ ordenes, vacio, accion, recibir }: {
  ordenes: OrdenCompraConsulta[]; vacio: string; accion?: string; recibir?: boolean
}) {
  if (ordenes.length === 0) return <SinRegistros icono="bi-check2-circle" titulo={vacio} />
  return (
    <ul className="cola">
      {ordenes.map((o) => (
        <li key={o.idOrdenCompra}>
          <Link to={recibir ? `/ordenes-compra/${o.idOrdenCompra}/recibir` : `/ordenes-compra/${o.idOrdenCompra}`} className="cola-item">
            <span className="cola-principal">
              <strong>{o.proveedor}</strong>
              <small>{o.numero} · entrega {formatoFecha(o.fechaEsperada)} · {o.bodega}</small>
            </span>
            <span className="cola-dato">
              <strong className="numero">{formatoMoneda(o.total)}</strong>
              {o.estaAtrasada ? <small className="texto-error">Atrasada</small> : <EstadoBadge estado={o.estado} />}
            </span>
            <span className="cola-accion">{recibir ? 'Recibir' : accion ?? 'Ver'} <i className="bi bi-chevron-right" /></span>
          </Link>
        </li>
      ))}
    </ul>
  )
}

export default InicioPage
