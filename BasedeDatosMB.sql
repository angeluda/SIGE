-- ============================================================
-- MÓDULO B — CONTROL DE INVENTARIOS
-- Sistema Integrado de Gestión Empresarial — Zapatería
-- ICC401 Bases de Datos II — Universidad del Azuay
-- Período: Febrero–Junio 2026
-- ============================================================

SET FOREIGN_KEY_CHECKS = 0;

-- ─────────────────────────────────────────────────────────────
-- TABLA 1: categorias_producto
-- Jerarquía de categorías con autorreferencia (EER)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS categorias_producto (
    categoria_id      INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    nombre            VARCHAR(100)  NOT NULL,
    descripcion       VARCHAR(255)  DEFAULT NULL,
    categoria_padre_id INT UNSIGNED DEFAULT NULL,
    nivel             TINYINT UNSIGNED NOT NULL DEFAULT 1,
    activo            TINYINT(1)    NOT NULL DEFAULT 1,
    PRIMARY KEY (categoria_id),
    INDEX idx_cat_padre (categoria_padre_id),
    CONSTRAINT fk_cat_padre FOREIGN KEY (categoria_padre_id)
        REFERENCES categorias_producto(categoria_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  COMMENT='Jerarquía de categorías de calzado (autorreferencia EER)';


-- ─────────────────────────────────────────────────────────────
-- TABLA 2: bodegas
-- Almacenes físicos de la zapatería
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS bodegas (
    bodega_id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
    codigo      VARCHAR(20)  NOT NULL,
    nombre      VARCHAR(100) NOT NULL,
    ubicacion   VARCHAR(200) DEFAULT NULL,
    responsable VARCHAR(150) DEFAULT NULL,
    activo      TINYINT(1)   NOT NULL DEFAULT 1,
    PRIMARY KEY (bodega_id),
    UNIQUE KEY uq_bodega_codigo (codigo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  COMMENT='Bodegas / almacenes de la zapatería';


-- ─────────────────────────────────────────────────────────────
-- TABLA 3: productos (ENTIDAD MAESTRA — PROVEE a Móds. A y C)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS productos (
    producto_id   INT UNSIGNED  NOT NULL AUTO_INCREMENT,   -- ← antes: product_id
    codigo        VARCHAR(50)   NOT NULL,
    descripcion   VARCHAR(255)  NOT NULL,
    categoria_id  INT UNSIGNED  NOT NULL,
    marca         VARCHAR(100)  DEFAULT NULL,
    modelo        VARCHAR(100)  DEFAULT NULL,
    talla         VARCHAR(10)   DEFAULT NULL,
    color         VARCHAR(50)   DEFAULT NULL,
    costo         DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    precio_venta  DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    stock_actual  INT           NOT NULL DEFAULT 0,
    stock_min     INT           NOT NULL DEFAULT 5,
    stock_max     INT           NOT NULL DEFAULT 100,
    activo        TINYINT(1)    NOT NULL DEFAULT 1,
    fecha_creacion DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CHECK (costo >= 0),
    CHECK (precio_venta >= 0),
    CHECK (stock_min >= 0),
    CHECK (stock_max > stock_min),
    PRIMARY KEY (producto_id),
    UNIQUE KEY uq_producto_codigo (codigo),
    INDEX idx_producto_categoria (categoria_id),
    INDEX idx_producto_marca (marca),
    INDEX idx_producto_talla (talla),
    CONSTRAINT fk_producto_categoria FOREIGN KEY (categoria_id)
        REFERENCES categorias_producto(categoria_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  COMMENT='Tabla maestra de productos — PROVEE a Módulo A (facturación) y Módulo C (compras)';


-- ─────────────────────────────────────────────────────────────
-- TABLA 4: movimientos_inventario
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS movimientos_inventario (
    movimiento_id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    producto_id   INT UNSIGNED NOT NULL,               -- ← antes: product_id
    bodega_id     INT UNSIGNED NOT NULL,
    tipo          ENUM('ENTRADA','SALIDA','AJUSTE') NOT NULL,
    cantidad      INT          NOT NULL,
    fecha         DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    referencia    VARCHAR(100) DEFAULT NULL
        COMMENT 'Nro de factura (Mód. A) o recepcion_id (Mód. C)',
    usuario_id    INT UNSIGNED DEFAULT NULL,
    observaciones VARCHAR(255) DEFAULT NULL,
    CHECK (cantidad > 0),
    PRIMARY KEY (movimiento_id),
    INDEX idx_mov_producto (producto_id),
    INDEX idx_mov_bodega   (bodega_id),
    INDEX idx_mov_fecha    (fecha),
    INDEX idx_mov_tipo     (tipo),
    CONSTRAINT fk_mov_producto FOREIGN KEY (producto_id)
        REFERENCES productos(producto_id),
    CONSTRAINT fk_mov_bodega FOREIGN KEY (bodega_id)
        REFERENCES bodegas(bodega_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  COMMENT='Registro de entradas, salidas y ajustes de inventario';


-- ─────────────────────────────────────────────────────────────
-- TABLA 5: kardex
-- Historial acumulativo por producto y bodega
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS kardex (
    kardex_id        INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    producto_id      INT UNSIGNED  NOT NULL,            -- ← antes: product_id
    bodega_id        INT UNSIGNED  NOT NULL,
    fecha            DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tipo_movimiento  ENUM('ENTRADA','SALIDA','AJUSTE') NOT NULL,
    cantidad_entrada INT           NOT NULL DEFAULT 0,
    cantidad_salida  INT           NOT NULL DEFAULT 0,
    stock_resultante INT           NOT NULL,
    costo_unitario   DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    costo_total      DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    referencia       VARCHAR(100)  DEFAULT NULL,
    PRIMARY KEY (kardex_id),
    INDEX idx_kardex_producto (producto_id),
    INDEX idx_kardex_fecha    (fecha),
    CONSTRAINT fk_kardex_producto FOREIGN KEY (producto_id)
        REFERENCES productos(producto_id),
    CONSTRAINT fk_kardex_bodega FOREIGN KEY (bodega_id)
        REFERENCES bodegas(bodega_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  COMMENT='Kardex: historial de saldos y costos por producto y bodega';

SET FOREIGN_KEY_CHECKS = 1;


-- ============================================================
-- DML — DATOS DE PRUEBA
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- DML: categorias_producto (10 filas)
-- ─────────────────────────────────────────────────────────────
INSERT INTO categorias_producto (categoria_id, nombre, descripcion, categoria_padre_id, nivel) VALUES
( 1, 'Calzado',           'Categoría raíz del módulo',                    NULL, 1),
( 2, 'Zapatos Formales',  'Calzado de vestir para dama y caballero',          1, 2),
( 3, 'Zapatos Casuales',  'Calzado de uso diario',                            1, 2),
( 4, 'Deportivos',        'Calzado para actividad física',                    1, 2),
( 5, 'Botas',             'Botas cortas y largas',                            1, 2),
( 6, 'Sandalias',         'Calzado abierto para temporada cálida',            1, 2),
( 7, 'Mocasines',         'Subcategoría de formales',                         2, 3),
( 8, 'Oxford',            'Subcategoría de formales con cordones',            2, 3),
( 9, 'Running',           'Subcategoría de deportivos',                       4, 3),
(10, 'Botines',           'Botas cortas de moda',                             5, 3);


-- ─────────────────────────────────────────────────────────────
-- DML: bodegas (5 filas)
-- ─────────────────────────────────────────────────────────────
INSERT INTO bodegas (bodega_id, codigo, nombre, ubicacion, responsable) VALUES
(1, 'BOD-01', 'Bodega Principal',   'Calle Larga 3-45, Cuenca',              'Carlos Vásquez'),
(2, 'BOD-02', 'Bodega Secundaria',  'Av. Remigio Crespo 7-23, Cuenca',       'María Flores'),
(3, 'BOD-03', 'Showroom Ventas',    'Centro Comercial Millenium',             'Ana Torres'),
(4, 'BOD-04', 'Bodega Outlet',      'Av. de las Américas, Cuenca',            'Pedro León'),
(5, 'BOD-05', 'Bodega Tránsito',    'Zona Industrial Norte',                  'Luis Mora');


-- ─────────────────────────────────────────────────────────────
-- DML: productos (20 filas) — PK ahora es producto_id
-- ─────────────────────────────────────────────────────────────
INSERT INTO productos
    (producto_id, codigo, descripcion, categoria_id, marca, modelo, talla, color,
     costo, precio_venta, stock_actual, stock_min, stock_max)
VALUES
( 1,'ZAP-F-001','Zapato Oxford Caballero Negro 40', 8,'Bata',      'Oxford Classic',  '40','Negro',   35.00,  75.00, 30, 5,  80),
( 2,'ZAP-F-002','Zapato Oxford Caballero Negro 41', 8,'Bata',      'Oxford Classic',  '41','Negro',   35.00,  75.00, 25, 5,  80),
( 3,'ZAP-F-003','Zapato Oxford Caballero Café 42',  8,'Bata',      'Oxford Classic',  '42','Café',    35.00,  75.00, 20, 5,  80),
( 4,'ZAP-F-004','Mocasín Dama Beige 36',            7,'Andrea',    'Moc Confort',     '36','Beige',   28.00,  65.00, 18, 5,  70),
( 5,'ZAP-F-005','Mocasín Dama Beige 37',            7,'Andrea',    'Moc Confort',     '37','Beige',   28.00,  65.00, 22, 5,  70),
( 6,'ZAP-C-001','Zapato Casual Caballero Gris 42',  3,'Vans',      'Era',             '42','Gris',    40.00,  90.00, 15, 5,  60),
( 7,'ZAP-C-002','Zapato Casual Dama Blanco 37',     3,'Vans',      'Era',             '37','Blanco',  40.00,  90.00, 12, 5,  60),
( 8,'ZAP-D-001','Zapatilla Running Hombre 43',      9,'Nike',      'Air Max',         '43','Rojo',    60.00, 130.00, 20, 5, 100),
( 9,'ZAP-D-002','Zapatilla Running Dama 38',        9,'Nike',      'Air Max',         '38','Rosa',    60.00, 130.00, 18, 5, 100),
(10,'ZAP-D-003','Zapatilla Crossfit 41',            4,'Adidas',    'Ultraboost',      '41','Azul',    55.00, 120.00, 25, 5, 100),
(11,'ZAP-B-001','Bota Cuero Caballero 42',          5,'Timberland','Field Boot',      '42','Café',    70.00, 160.00, 10, 3,  40),
(12,'ZAP-B-002','Botín Dama Tacón 37',             10,'Nine West', 'Botte',           '37','Negro',   50.00, 115.00, 14, 3,  50),
(13,'ZAP-B-003','Botín Dama Tacón 38',             10,'Nine West', 'Botte',           '38','Negro',   50.00, 115.00, 11, 3,  50),
(14,'ZAP-S-001','Sandalia Playa Dama 36',           6,'Havaianas', 'Slim',            '36','Turquesa',12.00,  30.00, 35, 8, 120),
(15,'ZAP-S-002','Sandalia Playa Dama 37',           6,'Havaianas', 'Slim',            '37','Turquesa',12.00,  30.00, 30, 8, 120),
(16,'ZAP-S-003','Sandalia Casual Caballero 42',     6,'Crocs',     'Classic',         '42','Gris',    18.00,  45.00, 20, 5,  80),
(17,'ZAP-D-004','Zapatilla Fútbol Sala 41',         4,'Puma',      'King',            '41','Amarillo',45.00, 100.00, 16, 5,  60),
(18,'ZAP-C-003','Tenis Casual Unisex 40',           3,'Converse',  'Chuck Taylor',    '40','Blanco',  38.00,  85.00, 22, 5,  80),
(19,'ZAP-F-006','Zapato Formal Dama Tacón 36',      2,'Aldo',      'Heeled Pump',     '36','Negro',   42.00,  95.00,  8, 3,  40),
(20,'ZAP-F-007','Zapato Formal Dama Tacón 37',      2,'Aldo',      'Heeled Pump',     '37','Negro',   42.00,  95.00,  9, 3,  40);


-- ─────────────────────────────────────────────────────────────
-- DML: movimientos_inventario (20 filas)
-- ─────────────────────────────────────────────────────────────
INSERT INTO movimientos_inventario
    (producto_id, bodega_id, tipo, cantidad, fecha, referencia, observaciones)
VALUES
( 1, 1,'ENTRADA',30,'2026-01-05 08:00:00','REC-001','Recepción inicial compra'),
( 2, 1,'ENTRADA',25,'2026-01-05 08:00:00','REC-001','Recepción inicial compra'),
( 3, 1,'ENTRADA',20,'2026-01-05 08:00:00','REC-001','Recepción inicial compra'),
( 8, 1,'ENTRADA',20,'2026-01-06 09:00:00','REC-002','Recepción Nike Air Max'),
( 9, 1,'ENTRADA',18,'2026-01-06 09:00:00','REC-002','Recepción Nike Air Max'),
(10, 1,'ENTRADA',25,'2026-01-07 10:00:00','REC-003','Recepción Adidas'),
( 1, 1,'SALIDA', 5, '2026-01-10 14:30:00','FAC-001','Venta a cliente'),
( 8, 1,'SALIDA', 3, '2026-01-11 11:00:00','FAC-002','Venta a cliente'),
( 4, 3,'ENTRADA',18,'2026-01-12 08:00:00','REC-004','Traslado a showroom'),
( 5, 3,'ENTRADA',22,'2026-01-12 08:00:00','REC-004','Traslado a showroom'),
( 2, 1,'SALIDA', 4, '2026-02-01 10:00:00','FAC-003','Venta a cliente'),
(11, 2,'ENTRADA',10,'2026-02-03 09:00:00','REC-005','Recepción Timberland'),
(12, 3,'ENTRADA',14,'2026-02-05 08:30:00','REC-006','Recepción Nine West'),
(14, 1,'ENTRADA',35,'2026-02-10 08:00:00','REC-007','Recepción Havaianas'),
(15, 1,'ENTRADA',30,'2026-02-10 08:00:00','REC-007','Recepción Havaianas'),
( 9, 1,'SALIDA', 5, '2026-02-15 16:00:00','FAC-004','Venta a cliente'),
(18, 2,'ENTRADA',22,'2026-02-18 09:00:00','REC-008','Recepción Converse'),
( 6, 1,'AJUSTE', 2, '2026-02-20 12:00:00','AJU-001','Ajuste por conteo físico'),
(19, 3,'ENTRADA', 8,'2026-02-22 08:00:00','REC-009','Recepción Aldo'),
(20, 3,'ENTRADA', 9,'2026-02-22 08:00:00','REC-009','Recepción Aldo');


-- ─────────────────────────────────────────────────────────────
-- DML: kardex (20 filas)
-- ─────────────────────────────────────────────────────────────
INSERT INTO kardex
    (producto_id, bodega_id, fecha, tipo_movimiento,
     cantidad_entrada, cantidad_salida, stock_resultante,
     costo_unitario, costo_total, referencia)
VALUES
( 1,1,'2026-01-05 08:00:00','ENTRADA',30, 0,30, 35.00,1050.00,'REC-001'),
( 2,1,'2026-01-05 08:00:00','ENTRADA',25, 0,25, 35.00, 875.00,'REC-001'),
( 3,1,'2026-01-05 08:00:00','ENTRADA',20, 0,20, 35.00, 700.00,'REC-001'),
( 8,1,'2026-01-06 09:00:00','ENTRADA',20, 0,20, 60.00,1200.00,'REC-002'),
( 9,1,'2026-01-06 09:00:00','ENTRADA',18, 0,18, 60.00,1080.00,'REC-002'),
(10,1,'2026-01-07 10:00:00','ENTRADA',25, 0,25, 55.00,1375.00,'REC-003'),
( 1,1,'2026-01-10 14:30:00','SALIDA',  0, 5,25, 35.00, 175.00,'FAC-001'),
( 8,1,'2026-01-11 11:00:00','SALIDA',  0, 3,17, 60.00, 180.00,'FAC-002'),
( 4,3,'2026-01-12 08:00:00','ENTRADA',18, 0,18, 28.00, 504.00,'REC-004'),
( 5,3,'2026-01-12 08:00:00','ENTRADA',22, 0,22, 28.00, 616.00,'REC-004'),
( 2,1,'2026-02-01 10:00:00','SALIDA',  0, 4,21, 35.00, 140.00,'FAC-003'),
(11,2,'2026-02-03 09:00:00','ENTRADA',10, 0,10, 70.00, 700.00,'REC-005'),
(12,3,'2026-02-05 08:30:00','ENTRADA',14, 0,14, 50.00, 700.00,'REC-006'),
(14,1,'2026-02-10 08:00:00','ENTRADA',35, 0,35, 12.00, 420.00,'REC-007'),
(15,1,'2026-02-10 08:00:00','ENTRADA',30, 0,30, 12.00, 360.00,'REC-007'),
( 9,1,'2026-02-15 16:00:00','SALIDA',  0, 5,13, 60.00, 300.00,'FAC-004'),
(18,2,'2026-02-18 09:00:00','ENTRADA',22, 0,22, 38.00, 836.00,'REC-008'),
( 6,1,'2026-02-20 12:00:00','AJUSTE',  2, 0,17, 40.00,  80.00,'AJU-001'),
(19,3,'2026-02-22 08:00:00','ENTRADA', 8, 0, 8, 42.00, 336.00,'REC-009'),
(20,3,'2026-02-22 08:00:00','ENTRADA', 9, 0, 9, 42.00, 378.00,'REC-009');


-- ============================================================
-- ENTREGABLE C — CONSULTAS DE INTEGRACIÓN
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- CONSULTA 1: Top 10 modelos más vendidos y su stock actual
-- Cruza: productos + movimientos_inventario (Mód. B)
--        con detalle_factura + facturas (Mód. A)
-- ─────────────────────────────────────────────────────────────
SELECT
    p.producto_id,
    p.codigo,
    p.descripcion,
    p.marca,
    p.talla,
    SUM(df.cantidad)                     AS total_unidades_vendidas,
    SUM(df.cantidad * df.precio_unitario) AS ingreso_total,
    p.stock_actual                        AS stock_disponible,
    p.stock_min,
    CASE
        WHEN p.stock_actual <= p.stock_min       THEN 'STOCK CRÍTICO'
        WHEN p.stock_actual <= p.stock_min * 2   THEN 'STOCK BAJO'
        ELSE 'STOCK OK'
    END AS estado_stock
FROM productos p
-- JOIN hacia Módulo A (Facturación): tabla detalle_factura
INNER JOIN detalle_factura df ON df.producto_id = p.producto_id
-- JOIN hacia Módulo A (Facturación): tabla facturas para filtrar año
INNER JOIN facturas f ON f.factura_id = df.factura_id
WHERE f.fecha >= '2026-01-01'
  AND f.estado IN ('EMITIDA','COBRADA')
  AND p.activo = 1
GROUP BY
    p.producto_id, p.codigo, p.descripcion,
    p.marca, p.talla, p.stock_actual, p.stock_min
ORDER BY total_unidades_vendidas DESC
LIMIT 10;

-- EXPLAIN de la Consulta 1
EXPLAIN SELECT
    p.producto_id, p.codigo, p.descripcion, p.marca, p.talla,
    SUM(df.cantidad) AS total_unidades_vendidas,
    p.stock_actual, p.stock_min
FROM productos p
INNER JOIN detalle_factura df ON df.producto_id = p.producto_id
INNER JOIN facturas f ON f.factura_id = df.factura_id
WHERE f.fecha >= '2026-01-01'
  AND f.estado IN ('EMITIDA','COBRADA')
  AND p.activo = 1
GROUP BY p.producto_id
ORDER BY total_unidades_vendidas DESC
LIMIT 10;


-- ─────────────────────────────────────────────────────────────
-- CONSULTA 2: Productos con salidas sin órdenes de compra
-- pendientes (cruza Módulo B ↔ Módulo C)
-- ─────────────────────────────────────────────────────────────
SELECT
    p.producto_id,
    p.codigo,
    p.descripcion,
    p.stock_actual,
    p.stock_min,
    SUM(mi.cantidad) AS total_salidas
FROM productos p
INNER JOIN movimientos_inventario mi
       ON mi.producto_id = p.producto_id
      AND mi.tipo = 'SALIDA'
      AND mi.fecha >= DATE_SUB(NOW(), INTERVAL 30 DAY)
-- LEFT JOIN hacia Módulo C (Cuentas por Pagar): detalle_orden_compra
LEFT JOIN detalle_orden_compra doc ON doc.producto_id = p.producto_id
LEFT JOIN ordenes_compra oc
       ON oc.orden_id = doc.orden_id
      AND oc.estado = 'PENDIENTE'
WHERE oc.orden_id IS NULL
GROUP BY p.producto_id, p.codigo, p.descripcion,
         p.stock_actual, p.stock_min
ORDER BY total_salidas DESC;
