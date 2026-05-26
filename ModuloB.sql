--------------------MODULO B------------------------
DROP DATABASE IF EXISTS modulo_b;
CREATE DATABASE modulo_b DEFAULT CHARACTER SET utf8mb4;
USE modulo_b;

SET FOREIGN_KEY_CHECKS = 0;

CREATE TABLE categorias_producto (
    categoria_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(255),
    categoria_padre_id INT UNSIGNED,
    nivel TINYINT UNSIGNED DEFAULT 1,
    activo TINYINT(1) DEFAULT 1,
    FOREIGN KEY (categoria_padre_id) REFERENCES categorias_producto(categoria_id)
);

CREATE TABLE bodegas (
    bodega_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(20) NOT NULL UNIQUE,
    nombre VARCHAR(100) NOT NULL,
    ubicacion VARCHAR(200),
    responsable VARCHAR(150),
    activo TINYINT(1) DEFAULT 1
);

CREATE TABLE productos (
    product_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(50) NOT NULL UNIQUE,
    descripcion VARCHAR(255) NOT NULL,
    categoria_id INT UNSIGNED NOT NULL,
    marca VARCHAR(100),
    modelo VARCHAR(100),
    talla VARCHAR(10),
    color VARCHAR(50),
    precio_costo DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    precio_venta DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    stock_actual INT NOT NULL DEFAULT 0,
    stock_minimo INT NOT NULL DEFAULT 5,
    stock_maximo INT NOT NULL DEFAULT 100,
    estado ENUM('ACTIVO','INACTIVO') NOT NULL DEFAULT 'ACTIVO',
    unidad_medida VARCHAR(50) DEFAULT 'unidad',
    fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (categoria_id) REFERENCES categorias_producto(categoria_id)
);

CREATE TABLE movimientos_inventario (
    movimiento_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    product_id INT UNSIGNED NOT NULL,
    bodega_id INT UNSIGNED NOT NULL,
    tipo_movimiento ENUM('ENTRADA','SALIDA','AJUSTE') NOT NULL,
    cantidad INT NOT NULL,
    fecha DATETIME DEFAULT CURRENT_TIMESTAMP,
    stock_anterior INT,
    stock_nuevo INT,
    referencia VARCHAR(100),
    motivo VARCHAR(255),
    FOREIGN KEY (product_id) REFERENCES productos(product_id),
    FOREIGN KEY (bodega_id) REFERENCES bodegas(bodega_id)
);

CREATE TABLE kardex (
    kardex_id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    product_id INT UNSIGNED NOT NULL,
    bodega_id INT UNSIGNED NOT NULL,
    fecha DATETIME DEFAULT CURRENT_TIMESTAMP,
    tipo_movimiento ENUM('ENTRADA','SALIDA','AJUSTE') NOT NULL,
    cantidad_entrada INT DEFAULT 0,
    cantidad_salida INT DEFAULT 0,
    stock_resultante INT NOT NULL,
    costo_unitario DECIMAL(10,2) DEFAULT 0.00,
    costo_total DECIMAL(10,2) DEFAULT 0.00,
    referencia VARCHAR(100),
    FOREIGN KEY (product_id) REFERENCES productos(product_id),
    FOREIGN KEY (bodega_id) REFERENCES bodegas(bodega_id)
);

CREATE TABLE alertas_reposicion (
    id_alerta INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    product_id INT UNSIGNED NOT NULL,
    stock_detectado INT NOT NULL,
    fecha_alerta DATETIME DEFAULT CURRENT_TIMESTAMP,
    estado ENUM('PENDIENTE','ATENDIDA','CANCELADA') DEFAULT 'PENDIENTE',
    FOREIGN KEY (product_id) REFERENCES productos(product_id)
);

CREATE TABLE solicitudes_compra (
    id_solicitud INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    product_id INT UNSIGNED NOT NULL,
    bodega_id INT UNSIGNED NOT NULL,
    cantidad_sugerida INT NOT NULL,
    fecha_solicitud DATETIME DEFAULT CURRENT_TIMESTAMP,
    estado ENUM('PENDIENTE','APROBADA','RECHAZADA') DEFAULT 'PENDIENTE',
    FOREIGN KEY (product_id) REFERENCES productos(product_id),
    FOREIGN KEY (bodega_id) REFERENCES bodegas(bodega_id)
);

SET FOREIGN_KEY_CHECKS = 1;

INSERT INTO categorias_producto VALUES
(1,'Calzado','Categoría principal',NULL,1,1),
(2,'Zapatos Formales','Zapatos elegantes',1,2,1),
(3,'Zapatos Casuales','Uso diario',1,2,1),
(4,'Deportivos','Calzado deportivo',1,2,1),
(5,'Botas','Botas y botines',1,2,1),
(6,'Sandalias','Calzado abierto',1,2,1),
(7,'Mocasines','Subcategoría formal',2,3,1),
(8,'Oxford','Subcategoría formal',2,3,1),
(9,'Running','Subcategoría deportiva',4,3,1),
(10,'Botines','Subcategoría botas',5,3,1);

INSERT INTO bodegas VALUES
(1,'BOD-01','Bodega Principal','Cuenca','Carlos Vásquez',1),
(2,'BOD-02','Bodega Secundaria','Cuenca','María Flores',1),
(3,'BOD-03','Showroom Ventas','Centro Comercial','Ana Torres',1);

INSERT INTO productos
(product_id,codigo,descripcion,categoria_id,marca,modelo,talla,color,precio_costo,precio_venta,stock_actual,stock_minimo,stock_maximo,estado,unidad_medida)
VALUES
(1,'ZAP-F-001','Zapato Oxford Caballero Negro 40',8,'Bata','Oxford Classic','40','Negro',35,75,30,5,80,'ACTIVO','unidad'),
(2,'ZAP-F-002','Zapato Oxford Caballero Negro 41',8,'Bata','Oxford Classic','41','Negro',35,75,25,5,80,'ACTIVO','unidad'),
(3,'ZAP-F-003','Zapato Oxford Caballero Café 42',8,'Bata','Oxford Classic','42','Café',35,75,20,5,80,'ACTIVO','unidad'),
(4,'ZAP-C-001','Zapato Casual Gris 42',3,'Vans','Era','42','Gris',40,90,15,5,60,'ACTIVO','unidad'),
(5,'ZAP-D-001','Zapatilla Running Hombre 43',9,'Nike','Air Max','43','Rojo',60,130,20,5,100,'ACTIVO','unidad'),
(6,'ZAP-B-001','Bota Cuero Caballero 42',5,'Timberland','Field Boot','42','Café',70,160,10,3,40,'ACTIVO','unidad'),
(7,'ZAP-S-001','Sandalia Playa Dama 36',6,'Havaianas','Slim','36','Turquesa',12,30,35,8,120,'ACTIVO','unidad'),
(8,'ZAP-F-004','Mocasín Dama Beige 36',7,'Andrea','Moc Confort','36','Beige',28,65,18,5,70,'ACTIVO','unidad'),
(9,'ZAP-D-002','Zapatilla Running Dama 38',9,'Nike','Air Max','38','Rosa',60,130,18,5,100,'ACTIVO','unidad'),
(10,'ZAP-F-005','Zapato Formal Dama Tacón 36',2,'Aldo','Heeled Pump','36','Negro',42,95,8,3,40,'ACTIVO','unidad');

INSERT INTO movimientos_inventario
(product_id,bodega_id,tipo_movimiento,cantidad,fecha,stock_anterior,stock_nuevo,referencia,motivo)
VALUES
(1,1,'ENTRADA',30,'2026-01-05 08:00:00',0,30,'REC-001','Recepción inicial'),
(2,1,'ENTRADA',25,'2026-01-05 08:00:00',0,25,'REC-001','Recepción inicial'),
(3,1,'ENTRADA',20,'2026-01-05 08:00:00',0,20,'REC-001','Recepción inicial'),
(5,1,'ENTRADA',20,'2026-01-06 09:00:00',0,20,'REC-002','Recepción Nike'),
(1,1,'SALIDA',5,'2026-01-10 14:30:00',30,25,'FAC-001','Venta a cliente');

INSERT INTO kardex
(product_id,bodega_id,fecha,tipo_movimiento,cantidad_entrada,cantidad_salida,stock_resultante,costo_unitario,costo_total,referencia)
VALUES
(1,1,'2026-01-05 08:00:00','ENTRADA',30,0,30,35,1050,'REC-001'),
(2,1,'2026-01-05 08:00:00','ENTRADA',25,0,25,35,875,'REC-001'),
(3,1,'2026-01-05 08:00:00','ENTRADA',20,0,20,35,700,'REC-001'),
(1,1,'2026-01-10 14:30:00','SALIDA',0,5,25,35,175,'FAC-001');

CREATE OR REPLACE VIEW v_stock_bajo_minimo AS
SELECT product_id,codigo,descripcion,stock_actual,stock_minimo,stock_maximo,estado
FROM productos
WHERE stock_actual <= stock_minimo
AND estado = 'ACTIVO';

CREATE OR REPLACE VIEW v_solicitudes_pendientes AS
SELECT sc.id_solicitud,p.product_id,p.codigo,p.descripcion,b.nombre AS bodega,
       sc.cantidad_sugerida,sc.fecha_solicitud,sc.estado
FROM solicitudes_compra sc
JOIN productos p ON p.product_id = sc.product_id
JOIN bodegas b ON b.bodega_id = sc.bodega_id
WHERE sc.estado = 'PENDIENTE';

DELIMITER $$

CREATE FUNCTION fn_stock_disponible(p_product_id INT)
RETURNS INT
DETERMINISTIC
BEGIN
    DECLARE v_stock INT;
    SELECT stock_actual INTO v_stock
    FROM productos
    WHERE product_id = p_product_id;
    RETURN v_stock;
END$$

CREATE PROCEDURE sp_registrar_salida_inventario(
    IN p_product_id INT,
    IN p_bodega_id INT,
    IN p_cantidad INT,
    IN p_referencia VARCHAR(100)
)
BEGIN
    DECLARE v_stock_actual INT;

    SELECT stock_actual INTO v_stock_actual
    FROM productos
    WHERE product_id = p_product_id;

    IF v_stock_actual < p_cantidad THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Stock insuficiente';
    ELSE
        UPDATE productos
        SET stock_actual = stock_actual - p_cantidad
        WHERE product_id = p_product_id;

        INSERT INTO movimientos_inventario
        (product_id,bodega_id,tipo_movimiento,cantidad,stock_anterior,stock_nuevo,referencia,motivo)
        VALUES
        (p_product_id,p_bodega_id,'SALIDA',p_cantidad,v_stock_actual,v_stock_actual - p_cantidad,p_referencia,'Salida automática');
    END IF;
END$$

CREATE PROCEDURE sp_registrar_entrada_inventario(
    IN p_product_id INT,
    IN p_bodega_id INT,
    IN p_cantidad INT,
    IN p_referencia VARCHAR(100)
)
BEGIN
    DECLARE v_stock_actual INT;

    SELECT stock_actual INTO v_stock_actual
    FROM productos
    WHERE product_id = p_product_id;

    UPDATE productos
    SET stock_actual = stock_actual + p_cantidad
    WHERE product_id = p_product_id;

    INSERT INTO movimientos_inventario
    (product_id,bodega_id,tipo_movimiento,cantidad,stock_anterior,stock_nuevo,referencia,motivo)
    VALUES
    (p_product_id,p_bodega_id,'ENTRADA',p_cantidad,v_stock_actual,v_stock_actual + p_cantidad,p_referencia,'Entrada automática');
END$$

CREATE PROCEDURE sp_verificar_stock_minimo()
BEGIN
    INSERT INTO alertas_reposicion(product_id,stock_detectado,fecha_alerta,estado)
    SELECT product_id,stock_actual,NOW(),'PENDIENTE'
    FROM productos
    WHERE stock_actual <= stock_minimo
    AND estado = 'ACTIVO';
END$$

CREATE TRIGGER trg_stock_after_update
AFTER UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NEW.stock_actual <= NEW.stock_minimo THEN
        INSERT INTO alertas_reposicion(product_id,stock_detectado,fecha_alerta,estado)
        VALUES(NEW.product_id,NEW.stock_actual,NOW(),'PENDIENTE');

        INSERT INTO solicitudes_compra(product_id,bodega_id,cantidad_sugerida,fecha_solicitud,estado)
        VALUES(NEW.product_id,1,NEW.stock_maximo - NEW.stock_actual,NOW(),'PENDIENTE');
    END IF;
END$$

DELIMITER ;

START TRANSACTION;
UPDATE productos SET stock_actual = stock_actual - 2 WHERE product_id = 1;
ROLLBACK;

CREATE ROLE IF NOT EXISTS rol_admin_inventario;
CREATE ROLE IF NOT EXISTS rol_consulta_inventario;

GRANT ALL PRIVILEGES ON modulo_b.* TO rol_admin_inventario;
GRANT SELECT ON modulo_b.* TO rol_consulta_inventario;

EXPLAIN
SELECT product_id,codigo,descripcion,stock_actual,stock_minimo
FROM productos
WHERE stock_actual <= stock_minimo
AND estado = 'ACTIVO';

EXPLAIN
SELECT mi.movimiento_id,p.codigo,p.descripcion,mi.tipo_movimiento,mi.cantidad,mi.fecha
FROM movimientos_inventario mi
JOIN productos p ON p.product_id = mi.product_id
WHERE mi.product_id = 1
ORDER BY mi.fecha DESC;

SELECT * FROM productos;
SELECT * FROM v_stock_bajo_minimo;
SELECT fn_stock_disponible(1);
CALL sp_registrar_salida_inventario(1,1,28,'FAC-001');
SELECT * FROM alertas_reposicion;
SELECT * FROM solicitudes_compra;
