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

CREATE TABLE clientes (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    tipo_cliente_id TINYINT UNSIGNED NOT NULL,
    direccion VARCHAR(255) NOT NULL,
    telefono VARCHAR(20),
    correo_electronico VARCHAR(100),
    dias_credito INT UNSIGNED NOT NULL DEFAULT 0,
    estado ENUM('ACTIVO', 'INACTIVO') NOT NULL DEFAULT 'ACTIVO', -- Se usa ENUM por ser binario estático
    CONSTRAINT fk_cliente_tipo FOREIGN KEY (tipo_cliente_id) REFERENCES cat_tipos_cliente(id) ON DELETE RESTRICT
);

CREATE TABLE personas_naturales (
    cliente_id INT UNSIGNED PRIMARY KEY,
    cedula VARCHAR(10) NOT NULL UNIQUE,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    CONSTRAINT fk_pnatural_cliente FOREIGN KEY (cliente_id) REFERENCES clientes(id) ON DELETE CASCADE,
    CONSTRAINT chk_cedula_len CHECK (CHAR_LENGTH(cedula) = 10)
);

CREATE TABLE personas_juridicas (
    cliente_id INT UNSIGNED PRIMARY KEY,
    ruc VARCHAR(13) NOT NULL UNIQUE,
    razon_social VARCHAR(150) NOT NULL,
    representante_legal VARCHAR(150),
    CONSTRAINT fk_pjuridica_cliente FOREIGN KEY (cliente_id) REFERENCES clientes(id) ON DELETE CASCADE,
    CONSTRAINT chk_ruc_len CHECK (CHAR_LENGTH(ruc) = 13)
);

CREATE TABLE vendedores (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    cedula VARCHAR(10) NOT NULL UNIQUE,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    zona VARCHAR(50) NOT NULL,
    porcentaje_comision DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    estado ENUM('ACTIVO', 'INACTIVO') NOT NULL DEFAULT 'ACTIVO'
);

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
    producto_id INT UNSIGNED NOT NULL COMMENT 'FK hacia Módulo B (Inventarios): modulo_b.productos.product_id',
    cantidad INT UNSIGNED NOT NULL,
    precio DECIMAL(10,2) NOT NULL,
    descuento DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    CONSTRAINT fk_detalle_factura FOREIGN KEY (factura_id) REFERENCES facturas(id) ON DELETE CASCADE,
    CONSTRAINT fk_detalle_producto FOREIGN KEY (producto_id) REFERENCES modulo_b.productos(product_id) ON DELETE RESTRICT
);
CREATE INDEX idx_detalle_producto ON detalle_factura(producto_id);

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
    CONSTRAINT fk_pago_factura FOREIGN KEY (factura_id) REFERENCES facturas(id) ON DELETE RESTRICT,
    CONSTRAINT fk_pago_forma FOREIGN KEY (forma_pago_id) REFERENCES cat_formas_pago(id) ON DELETE RESTRICT,
    CONSTRAINT chk_monto_pago CHECK (monto > 0)
);
