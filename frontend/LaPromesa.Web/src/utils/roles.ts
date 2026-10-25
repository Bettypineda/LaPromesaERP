// Mismas combinaciones de roles que RolesSistema.cs en el backend
export const ROLES = {
  Administrador: 'Administrador',
  Compras: 'Compras',
  Gerente: 'Gerente',
  Bodega: 'Bodega',
  Tesoreria: 'Tesoreria',
  Consulta: 'Consulta',
} as const

export const PERMISOS = {
  gestionarProveedores: ['Administrador', 'Compras'],
  autorizarCompras: ['Administrador', 'Gerente'],
  crearCompras: ['Administrador', 'Compras'],
  recibirMercaderia: ['Administrador', 'Bodega'],
  registrarPagos: ['Administrador', 'Tesoreria'],
  verFinanzas: ['Administrador', 'Tesoreria', 'Gerente', 'Consulta'],
  verReportes: ['Administrador', 'Gerente', 'Compras', 'Tesoreria', 'Consulta'],
} as const

export type Permiso = keyof typeof PERMISOS

export const tienePermiso = (rol: string | undefined, permiso: Permiso) =>
  !!rol && (PERMISOS[permiso] as readonly string[]).includes(rol)

export const DESCRIPCION_ROL: Record<string, string> = {
  Administrador: 'Acceso total al módulo',
  Compras: 'Proveedores y órdenes de compra',
  Gerente: 'Autoriza órdenes y revisa finanzas',
  Bodega: 'Recibe mercadería',
  Tesoreria: 'Cuentas por pagar y pagos',
  Consulta: 'Solo lectura',
}
