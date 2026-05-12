-- ============================================================
-- MODULO B - CONTROL DE INVENTARIOS
-- Base de datos para zapateria
-- Adaptado para Grupo 1 y Grupo 5
-- ============================================================

DROP DATABASE IF EXISTS modulo_b;
CREATE DATABASE modulo_b
DEFAULT CHARACTER SET utf8mb4
DEFAULT COLLATE utf8mb4_unicode_ci;

USE modulo_b;

-- ============================================================
-- TABLA: categorias_producto
-- ============================================================

CREATE TABLE categorias_producto (
    categoria_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(255),
    categoria_padre_id INT UNSIGNED NULL,
    nivel TINYINT UNSIGNED NOT NULL DEFAULT 1,
    activo TINYINT(1) NOT NULL DEFAULT 1,

    CONSTRAINT fk_categoria_padre
    FOREIGN KEY (categoria_padre_id)
    REFERENCES categorias_producto(categoria_id)
    ON DELETE RESTRICT
    ON UPDATE CASCADE
);

-- ============================================================
-- TABLA: bodegas
-- ============================================================

CREATE TABLE bodegas (
    bodega_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(20) NOT NULL UNIQUE,
    nombre VARCHAR(100) NOT NULL,
    ubicacion VARCHAR(200),
    responsable VARCHAR(150),
    activo TINYINT(1) NOT NULL DEFAULT 1
);

-- ============================================================
-- TABLA: productos
-- Esta tabla la usan Grupo 1 y Grupo 5
-- ============================================================

CREATE TABLE productos (
    product_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL UNIQUE,
    descripcion VARCHAR(255) NOT NULL,
    categoria_id INT UNSIGNED NOT NULL,
    marca VARCHAR(100),
    modelo VARCHAR(100),
    talla VARCHAR(10),
    color VARCHAR(50),
    costo DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    precio_venta DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    stock_actual INT NOT NULL DEFAULT 0,
    stock_min INT NOT NULL DEFAULT 5,
    stock_max INT NOT NULL DEFAULT 100,
    activo TINYINT(1) NOT NULL DEFAULT 1,
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_producto_categoria
    FOREIGN KEY (categoria_id)
    REFERENCES categorias_producto(categoria_id),

    CONSTRAINT chk_costo CHECK (costo >= 0),
    CONSTRAINT chk_precio CHECK (precio_venta >= 0),
    CONSTRAINT chk_stock_min CHECK (stock_min >= 0),
    CONSTRAINT chk_stock_max CHECK (stock_max > stock_min)
);

-- ============================================================
-- TABLA: movimientos_inventario
-- ============================================================

CREATE TABLE movimientos_inventario (
    movimiento_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    product_id INT UNSIGNED NOT NULL,
    bodega_id INT UNSIGNED NOT NULL,
    tipo ENUM('ENTRADA','SALIDA','AJUSTE') NOT NULL,
    cantidad INT NOT NULL,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    referencia VARCHAR(100),
    observaciones VARCHAR(255),

    CONSTRAINT fk_mov_producto
    FOREIGN KEY (product_id)
    REFERENCES productos(product_id),

    CONSTRAINT fk_mov_bodega
    FOREIGN KEY (bodega_id)
    REFERENCES bodegas(bodega_id),

    CONSTRAINT chk_mov_cantidad CHECK (cantidad > 0)
);

-- ============================================================
-- TABLA: kardex
-- ============================================================

CREATE TABLE kardex (
    kardex_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    product_id INT UNSIGNED NOT NULL,
    bodega_id INT UNSIGNED NOT NULL,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tipo_movimiento ENUM('ENTRADA','SALIDA','AJUSTE') NOT NULL,
    cantidad_entrada INT NOT NULL DEFAULT 0,
    cantidad_salida INT NOT NULL DEFAULT 0,
    stock_resultante INT NOT NULL,
    costo_unitario DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    costo_total DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    referencia VARCHAR(100),

    CONSTRAINT fk_kardex_producto
    FOREIGN KEY (product_id)
    REFERENCES productos(product_id),

    CONSTRAINT fk_kardex_bodega
    FOREIGN KEY (bodega_id)
    REFERENCES bodegas(bodega_id)
);

-- ============================================================
-- INDICES
-- ============================================================

CREATE INDEX idx_producto_categoria ON productos(categoria_id);
CREATE INDEX idx_producto_marca ON productos(marca);
CREATE INDEX idx_producto_talla ON productos(talla);

CREATE INDEX idx_mov_producto ON movimientos_inventario(product_id);
CREATE INDEX idx_mov_bodega ON movimientos_inventario(bodega_id);
CREATE INDEX idx_mov_fecha ON movimientos_inventario(fecha);
CREATE INDEX idx_mov_tipo ON movimientos_inventario(tipo);

CREATE INDEX idx_kardex_producto ON kardex(product_id);
CREATE INDEX idx_kardex_bodega ON kardex(bodega_id);
CREATE INDEX idx_kardex_fecha ON kardex(fecha);

-- ============================================================
-- DATOS DE PRUEBA
-- ============================================================

INSERT INTO categorias_producto
(categoria_id, nombre, descripcion, categoria_padre_id, nivel)
VALUES
(1, 'Calzado', 'Categoria principal', NULL, 1),
(2, 'Zapatos Formales', 'Calzado de vestir', 1, 2),
(3, 'Zapatos Casuales', 'Calzado diario', 1, 2),
(4, 'Deportivos', 'Calzado deportivo', 1, 2),
(5, 'Botas', 'Botas para dama y caballero', 1, 2),
(6, 'Sandalias', 'Calzado abierto', 1, 2),
(7, 'Mocasines', 'Subcategoria formal', 2, 3),
(8, 'Oxford', 'Zapatos con cordones', 2, 3),
(9, 'Running', 'Zapatillas para correr', 4, 3),
(10, 'Botines', 'Botas cortas', 5, 3);

INSERT INTO bodegas
(bodega_id, codigo, nombre, ubicacion, responsable)
VALUES
(1, 'BOD-01', 'Bodega Principal', 'Cuenca', 'Carlos Vasquez'),
(2, 'BOD-02', 'Bodega Secundaria', 'Cuenca', 'Maria Flores'),
(3, 'BOD-03', 'Showroom Ventas', 'Centro Comercial', 'Ana Torres'),
(4, 'BOD-04', 'Bodega Outlet', 'Av. Americas', 'Pedro Leon'),
(5, 'BOD-05', 'Bodega Transito', 'Zona Industrial', 'Luis Mora');

INSERT INTO productos
(product_id, codigo, descripcion, categoria_id, marca, modelo, talla, color,
 costo, precio_venta, stock_actual, stock_min, stock_max)
VALUES
(1,'ZAP-F-001','Zapato Oxford Caballero Negro 40',8,'Bata','Oxford Classic','40','Negro',35.00,75.00,30,5,80),
(2,'ZAP-F-002','Zapato Oxford Caballero Negro 41',8,'Bata','Oxford Classic','41','Negro',35.00,75.00,25,5,80),
(3,'ZAP-F-003','Zapato Oxford Caballero Cafe 42',8,'Bata','Oxford Classic','42','Cafe',35.00,75.00,20,5,80),
(4,'ZAP-F-004','Mocasin Dama Beige 36',7,'Andrea','Moc Confort','36','Beige',28.00,65.00,18,5,70),
(5,'ZAP-F-005','Mocasin Dama Beige 37',7,'Andrea','Moc Confort','37','Beige',28.00,65.00,22,5,70),
(6,'ZAP-C-001','Zapato Casual Caballero Gris 42',3,'Vans','Era','42','Gris',40.00,90.00,15,5,60),
(7,'ZAP-C-002','Zapato Casual Dama Blanco 37',3,'Vans','Era','37','Blanco',40.00,90.00,12,5,60),
(8,'ZAP-D-001','Zapatilla Running Hombre 43',9,'Nike','Air Max','43','Rojo',60.00,130.00,20,5,100),
(9,'ZAP-D-002','Zapatilla Running Dama 38',9,'Nike','Air Max','38','Rosa',60.00,130.00,18,5,100),
(10,'ZAP-D-003','Zapatilla Crossfit 41',4,'Adidas','Ultraboost','41','Azul',55.00,120.00,25,5,100),
(11,'ZAP-B-001','Bota Cuero Caballero 42',5,'Timberland','Field Boot','42','Cafe',70.00,160.00,10,3,40),
(12,'ZAP-B-002','Botin Dama Tacon 37',10,'Nine West','Botte','37','Negro',50.00,115.00,14,3,50),
(13,'ZAP-B-003','Botin Dama Tacon 38',10,'Nine West','Botte','38','Negro',50.00,115.00,11,3,50),
(14,'ZAP-S-001','Sandalia Playa Dama 36',6,'Havaianas','Slim','36','Turquesa',12.00,30.00,35,8,120),
(15,'ZAP-S-002','Sandalia Playa Dama 37',6,'Havaianas','Slim','37','Turquesa',12.00,30.00,8,8,120),
(16,'ZAP-S-003','Sandalia Casual Caballero 42',6,'Crocs','Classic','42','Gris',18.00,45.00,20,5,80),
(17,'ZAP-D-004','Zapatilla Futbol Sala 41',4,'Puma','King','41','Amarillo',45.00,100.00,16,5,60),
(18,'ZAP-C-003','Tenis Casual Unisex 40',3,'Converse','Chuck Taylor','40','Blanco',38.00,85.00,22,5,80),
(19,'ZAP-F-006','Zapato Formal Dama Tacon 36',2,'Aldo','Heeled Pump','36','Negro',8.00,95.00,2,3,40),
(20,'ZAP-F-007','Zapato Formal Dama Tacon 37',2,'Aldo','Heeled Pump','37','Negro',42.00,95.00,9,3,40);

-- ============================================================
-- PROCEDIMIENTO: ENTRADA DESDE GRUPO 5
-- ============================================================

DELIMITER $$

CREATE PROCEDURE sp_registrar_entrada_inventario_grupo5 (
    IN p_product_id INT UNSIGNED,
    IN p_bodega_id INT UNSIGNED,
    IN p_cantidad INT,
    IN p_id_recepcion INT UNSIGNED
)
BEGIN
    DECLARE v_stock_actual INT;
    DECLARE v_costo DECIMAL(10,2);

    START TRANSACTION;

    SELECT stock_actual, costo
    INTO v_stock_actual, v_costo
    FROM productos
    WHERE product_id = p_product_id
    FOR UPDATE;

    UPDATE productos
    SET stock_actual = stock_actual + p_cantidad
    WHERE product_id = p_product_id;

    INSERT INTO movimientos_inventario
    (product_id, bodega_id, tipo, cantidad, fecha, referencia, observaciones)
    VALUES
    (p_product_id, p_bodega_id, 'ENTRADA', p_cantidad, NOW(),
     CONCAT('REC-', p_id_recepcion),
     'Entrada generada desde recepcion del Grupo 5');

    INSERT INTO kardex
    (product_id, bodega_id, fecha, tipo_movimiento,
     cantidad_entrada, cantidad_salida, stock_resultante,
     costo_unitario, costo_total, referencia)
    VALUES
    (p_product_id, p_bodega_id, NOW(), 'ENTRADA',
     p_cantidad, 0, v_stock_actual + p_cantidad,
     v_costo, p_cantidad * v_costo, CONCAT('REC-', p_id_recepcion));

    COMMIT;
END$$

DELIMITER ;

-- ============================================================
-- PROCEDIMIENTO: SALIDA DESDE GRUPO 1
-- ============================================================

DELIMITER $$

CREATE PROCEDURE sp_registrar_salida_inventario_grupo1 (
    IN p_product_id INT UNSIGNED,
    IN p_bodega_id INT UNSIGNED,
    IN p_cantidad INT,
    IN p_factura_id INT UNSIGNED
)
BEGIN
    DECLARE v_stock_actual INT;
    DECLARE v_costo DECIMAL(10,2);

    START TRANSACTION;

    SELECT stock_actual, costo
    INTO v_stock_actual, v_costo
    FROM productos
    WHERE product_id = p_product_id
    FOR UPDATE;

    IF v_stock_actual < p_cantidad THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Stock insuficiente para registrar la salida';
    ELSE
        UPDATE productos
        SET stock_actual = stock_actual - p_cantidad
        WHERE product_id = p_product_id;

        INSERT INTO movimientos_inventario
        (product_id, bodega_id, tipo, cantidad, fecha, referencia, observaciones)
        VALUES
        (p_product_id, p_bodega_id, 'SALIDA', p_cantidad, NOW(),
         CONCAT('FAC-', p_factura_id),
         'Salida generada desde factura del Grupo 1');

        INSERT INTO kardex
        (product_id, bodega_id, fecha, tipo_movimiento,
         cantidad_entrada, cantidad_salida, stock_resultante,
         costo_unitario, costo_total, referencia)
        VALUES
        (p_product_id, p_bodega_id, NOW(), 'SALIDA',
         0, p_cantidad, v_stock_actual - p_cantidad,
         v_costo, p_cantidad * v_costo, CONCAT('FAC-', p_factura_id));

        COMMIT;
    END IF;
END$$

DELIMITER ;

-- ============================================================
-- FUNCION: STOCK DISPONIBLE
-- Grupo 1 puede consultar antes de facturar
-- ============================================================

DELIMITER $$

CREATE FUNCTION fn_stock_disponible (
    p_product_id INT UNSIGNED
)
RETURNS INT
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_stock INT;

    SELECT stock_actual
    INTO v_stock
    FROM productos
    WHERE product_id = p_product_id;

    RETURN IFNULL(v_stock, 0);
END$$

DELIMITER ;

-- ============================================================
-- VISTA: STOCK BAJO
-- Grupo 5 puede usarla para generar compras
-- ============================================================

CREATE OR REPLACE VIEW v_stock_bajo_minimo AS
SELECT
    product_id,
    codigo,
    descripcion,
    marca,
    modelo,
    talla,
    color,
    stock_actual,
    stock_min,
    stock_max,
    CASE
        WHEN stock_actual <= stock_min THEN 'REQUIERE REPOSICION'
        ELSE 'NORMAL'
    END AS estado_stock
FROM productos
WHERE activo = 1
AND stock_actual <= stock_min;

-- ============================================================
-- VISTA: INVENTARIO GENERAL
-- ============================================================

CREATE OR REPLACE VIEW v_inventario_general AS
SELECT
    p.product_id,
    p.codigo,
    p.descripcion,
    p.marca,
    p.modelo,
    p.talla,
    p.color,
    c.nombre AS categoria,
    p.costo,
    p.precio_venta,
    p.stock_actual,
    p.stock_min,
    p.stock_max,
    CASE
        WHEN p.stock_actual <= p.stock_min THEN 'STOCK BAJO'
        WHEN p.stock_actual >= p.stock_max THEN 'STOCK ALTO'
        ELSE 'STOCK NORMAL'
    END AS estado_inventario
FROM productos p
INNER JOIN categorias_producto c
ON c.categoria_id = p.categoria_id
WHERE p.activo = 1;

-- ============================================================
-- PRUEBAS DEL MODULO B
-- ============================================================

-- Entrada desde Grupo 5
CALL sp_registrar_entrada_inventario_grupo5(1, 1, 10, 101);

-- Salida desde Grupo 1
CALL sp_registrar_salida_inventario_grupo1(1, 1, 5, 201);

-- Ver stock disponible
SELECT fn_stock_disponible(1) AS stock_disponible;

-- Ver stock bajo
SELECT * FROM v_stock_bajo_minimo;

-- Ver inventario general
SELECT * FROM v_inventario_general;

-- Ver movimientos
SELECT * FROM movimientos_inventario;

-- Ver kardex
SELECT * FROM kardex;

-- ============================================================
-- CONSULTA DE INTEGRACION CON GRUPO 1
-- IMPORTANTE:
-- Esta consulta solo funciona cuando tambien este cargada
-- la base o tablas del Grupo 1.
-- ============================================================

/*
SELECT
    p.product_id,
    p.codigo,
    p.descripcion,
    p.marca,
    p.talla,
    SUM(df.cantidad) AS total_unidades_vendidas,
    SUM(df.cantidad * df.precio) AS ingreso_total,
    p.stock_actual AS stock_disponible,
    p.stock_min,
    CASE
        WHEN p.stock_actual <= p.stock_min THEN 'STOCK CRITICO'
        WHEN p.stock_actual <= p.stock_min * 2 THEN 'STOCK BAJO'
        ELSE 'STOCK OK'
    END AS estado_stock
FROM productos p
INNER JOIN detalle_factura df
    ON df.producto_id = p.product_id
INNER JOIN facturas f
    ON f.id = df.factura_id
WHERE f.fecha_emision >= '2026-01-01'
  AND f.estado_id IN (1,3)
  AND p.activo = 1
GROUP BY
    p.product_id,
    p.codigo,
    p.descripcion,
    p.marca,
    p.talla,
    p.stock_actual,
    p.stock_min
ORDER BY total_unidades_vendidas DESC
LIMIT 10;
*/

-- ============================================================
-- CONSULTA DE INTEGRACION CON GRUPO 5
-- IMPORTANTE:
-- Esta consulta solo funciona cuando tambien este cargada
-- la base o tablas del Grupo 5.
-- ============================================================

/*
SELECT
    p.product_id,
    p.codigo,
    p.descripcion,
    p.stock_actual,
    p.stock_min,
    SUM(mi.cantidad) AS total_salidas
FROM productos p
INNER JOIN movimientos_inventario mi
    ON mi.product_id = p.product_id
   AND mi.tipo = 'SALIDA'
   AND mi.fecha >= DATE_SUB(NOW(), INTERVAL 30 DAY)
LEFT JOIN detalle_orden_compra doc
    ON doc.ref_mod_b_id_producto = p.product_id
LEFT JOIN ordenes_compra oc
    ON oc.id_oc = doc.id_oc
   AND oc.estado IN ('borrador','enviada','recibida_parcial')
WHERE oc.id_oc IS NULL
GROUP BY
    p.product_id,
    p.codigo,
    p.descripcion,
    p.stock_actual,
    p.stock_min
ORDER BY total_salidas DESC;
*/
