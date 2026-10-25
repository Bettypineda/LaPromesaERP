/* =========================================================
   La Promesa ERP - Datos de prueba FICTICIOS
   Bodegas y productos de apoyo para el proceso de compras.
   Script repetible: no duplica si se ejecuta dos veces.
   ========================================================= */
USE LaPromesaERP;
GO

MERGE dbo.Bodegas AS t
USING (VALUES
 (N'Bodega Central', N'Cuilapa, Santa Rosa'),
 (N'Bodega Barberena', N'Barberena, Santa Rosa'),
 (N'Bodega Chiquimulilla', N'Chiquimulilla, Santa Rosa'),
 (N'Bodega Escuintla', N'Escuintla, Escuintla'),
 (N'Bodega Jutiapa', N'Jutiapa, Jutiapa')
) AS s(Nombre, Ubicacion) ON t.Nombre = s.Nombre
WHEN NOT MATCHED THEN INSERT (Nombre, Ubicacion) VALUES (s.Nombre, s.Ubicacion);
GO

MERGE dbo.Productos AS t
USING (VALUES
 ('PRD-001', N'Azúcar blanca 1 lb', N'Unidad', 4.25),
 ('PRD-002', N'Arroz blanco 1 lb', N'Unidad', 5.10),
 ('PRD-003', N'Aceite vegetal 1 L', N'Unidad', 18.75),
 ('PRD-004', N'Gaseosa 2.5 L', N'Unidad', 14.50),
 ('PRD-005', N'Leche entera 1 L', N'Unidad', 10.90),
 ('PRD-006', N'Frijol negro 1 lb', N'Unidad', 7.35)
) AS s(Codigo, Nombre, UnidadMedida, CostoPromedio) ON t.Codigo = s.Codigo
WHEN NOT MATCHED THEN INSERT (Codigo, Nombre, UnidadMedida, CostoPromedio)
                      VALUES (s.Codigo, s.Nombre, s.UnidadMedida, s.CostoPromedio);
GO

MERGE dbo.Proveedores AS t
USING (VALUES
 ('PR001', N'Distribuidora La Universal',  '80012345-6', N'Mario Pérez',   '2360-1111', N'ventas@launiversal.test', N'Km 12.5 Carretera al Atlántico', N'Abarrotes', 'Credito', 30),
 ('PR002', N'Polosur S.A.',                '80023456-7', N'Ana López',     '2360-2222', N'pedidos@polosur.test',    N'Mixco zona 3',                   N'Bebidas',   'Credito', 15),
 ('PR003', N'Productos Alimenticios S.A.', '80034567-8', N'Carlos Ruiz',   '2360-3333', N'info@proalim.test',       N'Villa Nueva',                    N'Abarrotes', 'Contado',  0),
 ('PR004', N'Bebidas de Guatemala',        '80045678-9', N'Lucía Mendoza', '2360-4444', N'ventas@bebidasgt.test',   N'Zona 12, Guatemala',             N'Bebidas',   'Credito', 30),
 ('PR005', N'Lácteos del Sur',             '80056789-0', N'Jorge Castillo','7880-5555', N'ventas@lacteossur.test',  N'Escuintla',                      N'Lácteos',   'Credito', 15),
 ('PR006', N'Granos Santa Rosa',           '80067890-1', N'María Ortiz',   '7886-6666', N'granos@santarosa.test',   N'Cuilapa, Santa Rosa',            N'Granos',    'Contado',  0)
) AS s(Codigo, Nombre, Nit, Contacto, Telefono, Email, Direccion, Categoria, TipoPago, DiasCredito)
ON t.Codigo = s.Codigo
WHEN NOT MATCHED THEN INSERT (Codigo, Nombre, Nit, Contacto, Telefono, Email, Direccion, Categoria, TipoPago, DiasCredito, CreadoPor)
VALUES (s.Codigo, s.Nombre, s.Nit, s.Contacto, s.Telefono, s.Email, s.Direccion, s.Categoria, s.TipoPago, s.DiasCredito, N'seed');
GO

SELECT 'Bodegas' AS Tabla, COUNT(*) AS Registros FROM dbo.Bodegas
UNION ALL SELECT 'Productos', COUNT(*) FROM dbo.Productos
UNION ALL SELECT 'Proveedores', COUNT(*) FROM dbo.Proveedores;
GO
