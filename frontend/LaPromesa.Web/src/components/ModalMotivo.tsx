import { useState } from 'react'
import Modal from './Modal'

interface Props {
  abierto: boolean
  titulo: string
  descripcion: string
  textoBoton: string
  procesando: boolean
  onConfirmar: (motivo: string) => void
  onCerrar: () => void
}

// Pide el motivo de una eliminación lógica (mínimo 10 caracteres, igual que la base de datos)
function ModalMotivo({ abierto, titulo, descripcion, textoBoton, procesando, onConfirmar, onCerrar }: Props) {
  const [motivo, setMotivo] = useState('')
  const [intento, setIntento] = useState(false)
  const error = motivo.trim().length < 10 ? 'Escriba el motivo (mínimo 10 caracteres).' : ''

  const cerrar = () => {
    setMotivo('')
    setIntento(false)
    onCerrar()
  }

  const confirmar = () => {
    setIntento(true)
    if (!error) onConfirmar(motivo.trim())
  }

  return (
    <Modal abierto={abierto} titulo={titulo} onCerrar={cerrar}
      pie={<>
        <button type="button" className="btn btn-claro" onClick={cerrar} disabled={procesando}>Cancelar</button>
        <button type="button" className="btn btn-peligro" onClick={confirmar} disabled={procesando}>
          {procesando ? 'Guardando…' : textoBoton}
        </button>
      </>}>
      <p className="texto-suave">{descripcion}</p>
      <label htmlFor="motivo" className="form-label">Motivo</label>
      <textarea id="motivo" className={`form-control ${intento && error ? 'is-invalid' : ''}`} rows={3} maxLength={300}
        value={motivo} onChange={(e) => setMotivo(e.target.value)} />
      {intento && error && <div className="invalid-feedback">{error}</div>}
      <div className="form-text">{motivo.trim().length}/300 · queda registrado en la bitácora con su usuario.</div>
    </Modal>
  )
}

export default ModalMotivo
