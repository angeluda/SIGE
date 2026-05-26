-- DDL MÓDULO A — Facturación y Cuentas por Cobrar

-- TABLAS DE CATÁLOGO
CREATE TABLE cat_tipos_cliente (
    id TINYINT UNSIGNED PRIMARY KEY,
    nombre VARCHAR(30) NOT NULL UNIQUE
);

INSERT INTO cat_tipos_cliente (id, nombre) VALUES (1, 'NATURAL'), (2, 'JURIDICA');

CREATE TABLE cat_estados_facturas (
    id TINYINT UNSIGNED PRIMARY KEY,
    nombre VARCHAR(20) NOT NULL
);

INSERT INTO cat_estados_facturas (id, nombre) VALUES
(1, 'PENDIENTE'), (2, 'VENCIDA'), (3, 'PAGADA'), (4, 'ANULADA');

CREATE TABLE cat_estados_cxc (
    id TINYINT UNSIGNED PRIMARY KEY,
    nombre VARCHAR(20) NOT NULL
);

INSERT INTO cat_estados_cxc (id, nombre) VALUES
(1, 'AL_DIA'), (2, 'EN_MORA'), (3, 'CANCELADA');

CREATE TABLE cat_formas_pago (
    id TINYINT UNSIGNED PRIMARY KEY,
    nombre VARCHAR(30) NOT NULL
);

INSERT INTO cat_formas_pago (id, nombre) VALUES
(1, 'EFECTIVO'), (2, 'TRANSFERENCIA'), (3, 'CHEQUE'), (4, 'TARJETA DE CRÉDITO');

-- CLIENTES
CREATE TABLE clientes (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    tipo_cliente_id TINYINT UNSIGNED NOT NULL,
    direccion VARCHAR(255) NOT NULL,
    telefono VARCHAR(20),
    correo_electronico VARCHAR(100),
    dias_credito INT UNSIGNED NOT NULL DEFAULT 0,
    estado ENUM('ACTIVO','INACTIVO') NOT NULL DEFAULT 'ACTIVO',
    
    CONSTRAINT fk_cliente_tipo FOREIGN KEY (tipo_cliente_id)
        REFERENCES cat_tipos_cliente(id) ON DELETE RESTRICT
);

CREATE TABLE personas_naturales (
    cliente_id INT UNSIGNED PRIMARY KEY,
    cedula VARCHAR(10) NOT NULL UNIQUE,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    
    CONSTRAINT fk_pnatural_cliente FOREIGN KEY (cliente_id)
        REFERENCES clientes(id) ON DELETE CASCADE,
    CONSTRAINT chk_cedula_len CHECK (CHAR_LENGTH(cedula) = 10)
);

CREATE TABLE personas_juridicas (
    cliente_id INT UNSIGNED PRIMARY KEY,
    ruc VARCHAR(13) NOT NULL UNIQUE,
    razon_social VARCHAR(150) NOT NULL,
    representante_legal VARCHAR(150),
    
    CONSTRAINT fk_pjuridica_cliente FOREIGN KEY (cliente_id)
        REFERENCES clientes(id) ON DELETE CASCADE,
    CONSTRAINT chk_ruc_len CHECK (CHAR_LENGTH(ruc) = 13)
);

-- VENDEDORES
CREATE TABLE vendedores (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    cedula VARCHAR(10) NOT NULL UNIQUE,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    zona VARCHAR(50) NOT NULL,
    porcentaje_comision DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    estado ENUM('ACTIVO','INACTIVO') NOT NULL DEFAULT 'ACTIVO'
);

-- FACTURACIÓN Y DETALLES
CREATE TABLE facturas (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    numero_factura VARCHAR(20) NOT NULL UNIQUE,
    fecha_emision DATE NOT NULL,
    total DECIMAL(10,2) NOT NULL,
    cliente_id INT UNSIGNED NOT NULL,
    vendedor_id INT UNSIGNED NOT NULL,
    estado_id TINYINT UNSIGNED NOT NULL DEFAULT 1,
    
    CONSTRAINT fk_factura_cliente FOREIGN KEY (cliente_id) REFERENCES clientes(id) ON DELETE RESTRICT,
    CONSTRAINT fk_factura_vendedor FOREIGN KEY (vendedor_id) REFERENCES vendedores(id) ON DELETE RESTRICT,
    CONSTRAINT fk_factura_estado FOREIGN KEY (estado_id) REFERENCES cat_estados_facturas(id) ON DELETE RESTRICT
);

CREATE TABLE detalle_factura (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    factura_id INT UNSIGNED NOT NULL,
    product_id INT UNSIGNED NOT NULL COMMENT 'FK hacia Módulo B (Inventarios)',
    id_tarifa INT UNSIGNED NOT NULL COMMENT 'FK hacia Módulo D (Impuestos)',
    cantidad INT UNSIGNED NOT NULL,
    precio_unitario DECIMAL(10,2) NOT NULL,
    descuento DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    CONSTRAINT fk_detalle_factura FOREIGN KEY (factura_id) REFERENCES facturas(id) ON DELETE CASCADE,
    
    -- LLAVES FORÁNEAS CRUZADAS (Integración con otros módulos)
    CONSTRAINT fk_detalle_producto FOREIGN KEY (product_id) REFERENCES modulo_b.productos(product_id) ON DELETE RESTRICT,
    CONSTRAINT fk_detalle_tarifa FOREIGN KEY (id_tarifa) REFERENCES modulo_d.tarifas_iva(id_tarifa) ON DELETE RESTRICT
);
CREATE INDEX idx_detalle_producto ON detalle_factura(id_producto);
CREATE INDEX idx_detalle_tarifa ON detalle_factura(id_tarifa);

-- CUENTAS POR COBRAR Y PAGOS
CREATE TABLE cuentas_por_cobrar (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    factura_id INT UNSIGNED NOT NULL UNIQUE,
    fecha_vencimiento DATE NOT NULL,
    saldo_pendiente DECIMAL(10,2) NOT NULL,
    estado_id TINYINT UNSIGNED NOT NULL DEFAULT 1,
    
    CONSTRAINT fk_cxc_factura FOREIGN KEY (factura_id) REFERENCES facturas(id) ON DELETE RESTRICT,
    CONSTRAINT fk_cxc_estado FOREIGN KEY (estado_id) REFERENCES cat_estados_cxc(id) ON DELETE RESTRICT
);

CREATE TABLE pagos_cliente (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    factura_id INT UNSIGNED NOT NULL,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    monto DECIMAL(10,2) NOT NULL,
    forma_pago_id TINYINT UNSIGNED NOT NULL,
    anulado TINYINT(1) NOT NULL DEFAULT 0 COMMENT 'Borrado lógico',
    
    CONSTRAINT fk_pago_factura FOREIGN KEY (factura_id) REFERENCES facturas(id) ON DELETE RESTRICT,
    CONSTRAINT fk_pago_forma FOREIGN KEY (forma_pago_id) REFERENCES cat_formas_pago(id) ON DELETE RESTRICT,
    CONSTRAINT chk_monto_pago CHECK (monto > 0)
);

-- DATOS DE PRUEBA

-- Clientes
INSERT INTO clientes (tipo_cliente_id, direccion, telefono, correo_electronico, dias_credito) VALUES
(1, 'Av. Solano 1-23', '0991234567', 'juan.perez@email.com', 0),
(1, 'Calle Larga 5-42', '0987654321', 'maria.gomez@email.com', 0),
(2, 'Parque Industrial', '072800111', 'pagos@zapatosec.com', 30);

INSERT INTO personas_naturales (cliente_id, cedula, nombres, apellidos) VALUES
(1, '0101234567', 'Juan Carlos', 'Pérez'),
(2, '0109876543', 'Maria Fernanda', 'Gómez');

INSERT INTO personas_juridicas (cliente_id, ruc, razon_social, representante_legal) VALUES
(3, '0190001234001', 'Zapatos Ecuador S.A.', 'Luis Andrade');

-- Vendedores
INSERT INTO vendedores (cedula, nombres, apellidos, zona, porcentaje_comision) VALUES
('0102223334', 'Pedro', 'Ramírez', 'Centro', 2.50),
('0105556667', 'Ana', 'Torres', 'Norte', 2.50);

-- Facturas
INSERT INTO facturas (numero_factura, fecha_emision, total, cliente_id, vendedor_id, estado_id) VALUES
('FAC-000001', '2026-05-01', 150.00, 1, 1, 3), -- Pagada
('FAC-000002', '2026-05-02', 260.00, 2, 2, 1), -- Pendiente
('FAC-000003', '2026-05-05', 300.00, 3, 1, 1), -- Pendiente
('FAC-000004', '2026-05-10', 75.00, 1, 2, 2),  -- Vencida
('FAC-000005', '2026-05-15', 90.00, 2, 1, 1);  -- Pendiente

-- Detalles de Factura
-- Las tarifas IVA (1=0%, 2=5%, 3=15%) están alineadas al Módulo D
INSERT INTO detalle_factura (factura_id, id_producto, id_tarifa, cantidad, precio_unitario, descuento) VALUES
-- Factura 1
(1, 1, 3, 2, 75.00, 0.00),   -- Producto 1: Zapato Oxford 
-- Factura 2
(2, 8, 3, 2, 130.00, 0.00),  -- Producto 8: Zapatilla Running
-- Factura 3
(3, 10, 3, 2, 120.00, 0.00), -- Producto 10: Crossfit
(3, 6, 3, 1, 90.00, 30.00),  -- Producto 6: Casual
-- Factura 4
(4, 3, 3, 1, 75.00, 0.00),   -- Producto 3: Oxford Cafe
-- Factura 5
(5, 7, 3, 1, 90.00, 0.00),   -- Producto 7: Casual Dama
-- Más detalles aleatorios para cumplir requerimiento de volumen de datos:
(1, 14, 2, 1, 30.00, 0.00),
(2, 15, 2, 2, 30.00, 0.00),
(3, 16, 2, 1, 45.00, 0.00),
(4, 18, 2, 1, 85.00, 0.00),
(5, 19, 3, 1, 95.00, 0.00),
(1, 20, 3, 1, 95.00, 0.00),
(2, 11, 3, 1, 160.00, 0.00),
(3, 12, 3, 1, 115.00, 0.00),
(4, 13, 3, 1, 115.00, 0.00),
(5, 4, 3, 1, 65.00, 0.00),
(1, 5, 3, 1, 65.00, 0.00),
(2, 9, 3, 1, 130.00, 0.00),
(3, 17, 3, 1, 100.00, 0.00),
(4, 2, 3, 1, 75.00, 0.00);

-- Cuentas por Cobrar
INSERT INTO cuentas_por_cobrar (factura_id, fecha_vencimiento, saldo_pendiente, estado_id) VALUES
(1, '2026-05-01', 0.00, 3),   -- Cancelada
(2, '2026-05-15', 260.00, 1), -- Al día
(3, '2026-06-05', 300.00, 1), -- Al día
(4, '2026-05-10', 75.00, 2),  -- En Mora
(5, '2026-05-30', 90.00, 1);  -- Al día

-- Pagos (Para la factura 1 que está pagada en su totalidad)
INSERT INTO pagos_cliente (factura_id, monto, forma_pago_id, anulado) VALUES
(1, 150.00, 1, 0); -- Pago en efectivo