export interface IniciarSesion {
  usuario: string
  contrasena: string
}

export interface UsuarioSesion {
  idUsuario: number
  usuario: string
  nombreCompleto: string
  rol: string
}

export interface Token {
  accessToken: string
  accessTokenExpira: string
  refreshToken: string
  refreshTokenExpira: string
  usuario: UsuarioSesion
}
