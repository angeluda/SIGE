-- ======================================================
-- MODULO D - VERSION CORREGIDA Y NORMALIZADA
-- ======================================================

-- ======================================================
-- 1. PARAMETRIZACION Y CONFIGURACION
-- ======================================================

CREATE TABLE tarifas_iva (
    id_tarifa INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(10) NOT NULL UNIQUE,
    porcentaje DECIMAL(5,2) NOT NULL,
    descripcion VARCHAR(100),
    fecha_vigencia_desde DATE NOT NULL,
    fecha_vigencia_hasta DATE,
    activo TINYINT(1) DEFAULT 1,

    CONSTRAINT chk_tarifa_porcentaje
    CHECK (porcentaje >= 0)
) ENGINE=InnoDB;

-- ======================================================
-- CATALOGO TIPOS DE PROVEEDOR
-- Evita VARCHAR repetidos e inconsistentes
-- ======================================================

CREATE TABLE cat_tipos_proveedor (
    id_tipo_proveedor TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE,
    descripcion VARCHAR(150),
    activo TINYINT(1) DEFAULT 1
) ENGINE=InnoDB;

-- ======================================================
-- CONFIGURACION RETENCIONES IVA
-- NORMALIZADA
-- ======================================================

CREATE TABLE retenciones_iva_config (
    id_ret_iva INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo_sri VARCHAR(10) NOT NULL UNIQUE,

    id_tipo_proveedor TINYINT UNSIGNED NOT NULL,

    porcentaje_retencion DECIMAL(5,2) NOT NULL,

    descripcion VARCHAR(150),

    activo TINYINT(1) DEFAULT 1,

    CONSTRAINT fk_ret_iva_tipo_proveedor
    FOREIGN KEY (id_tipo_proveedor)
    REFERENCES cat_tipos_proveedor(id_tipo_proveedor),

    CONSTRAINT chk_ret_iva_porcentaje
    CHECK (porcentaje_retencion >= 0
       AND porcentaje_retencion <= 100)
) ENGINE=InnoDB;

-- ======================================================
-- NUEVA TABLA:
-- CONFIGURACION RETENCIONES RENTA
-- ======================================================

CREATE TABLE retenciones_renta_config (
    id_ret_renta INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    codigo_sri VARCHAR(10) NOT NULL UNIQUE,

    porcentaje_retencion DECIMAL(5,2) NOT NULL,

    concepto VARCHAR(150) NOT NULL,

    descripcion VARCHAR(255),

    activo TINYINT(1) DEFAULT 1,

    CONSTRAINT chk_ret_renta_porcentaje
    CHECK (porcentaje_retencion >= 0
       AND porcentaje_retencion <= 100)
) ENGINE=InnoDB;

-- ======================================================
-- 2. LIQUIDACION IVA
-- ======================================================

CREATE TABLE liquidacion_iva_mensual (
    id_liquidacion INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    periodo DATE NOT NULL UNIQUE,

    iva_cobrado_ventas DECIMAL(10,2) DEFAULT 0.00,

    iva_pagado_compras DECIMAL(10,2) DEFAULT 0.00,

    credito_tributario_anterior DECIMAL(10,2) DEFAULT 0.00,

    iva_a_pagar DECIMAL(10,2) DEFAULT 0.00,

    saldo_credito DECIMAL(10,2) DEFAULT 0.00,

    estado ENUM(
        'borrador',
        'declarado',
        'cerrado'
    ) DEFAULT 'borrador'
) ENGINE=InnoDB;

-- ======================================================
-- COMPROBANTES DE RETENCION
-- VERSION NORMALIZADA
-- ======================================================

CREATE TABLE comprobantes_retencion (
    id_comprobante BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    numero VARCHAR(20) NOT NULL UNIQUE,

    fecha DATE NOT NULL,

    proveedor_id INT UNSIGNED NOT NULL,

    factura_compra_id INT UNSIGNED NOT NULL,

    base_imponible_renta DECIMAL(10,2) NOT NULL,

    id_ret_renta INT UNSIGNED NOT NULL,

    valor_retencion_renta DECIMAL(10,2) NOT NULL,

    base_imponible_iva DECIMAL(10,2) NOT NULL,

    id_ret_iva INT UNSIGNED NOT NULL,

    valor_retencion_iva DECIMAL(10,2) NOT NULL,

    xml_generado LONGTEXT,

    numero_autorizacion_simulado VARCHAR(50),

    fecha_generacion TIMESTAMP
    DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_comp_ret_renta
    FOREIGN KEY (id_ret_renta)
    REFERENCES retenciones_renta_config(id_ret_renta),

    CONSTRAINT fk_comp_ret_iva
    FOREIGN KEY (id_ret_iva)
    REFERENCES retenciones_iva_config(id_ret_iva),

    INDEX idx_ret_compra (factura_compra_id),

    CONSTRAINT chk_base_renta
    CHECK (base_imponible_renta >= 0),

    CONSTRAINT chk_base_iva
    CHECK (base_imponible_iva >= 0)
) ENGINE=InnoDB;

-- ======================================================
-- LOG XML
-- ======================================================

CREATE TABLE log_xml_comprobantes (
    id_log BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    tipo ENUM(
        'FACTURA',
        'RETENCION'
    ) NOT NULL,

    referencia_id BIGINT UNSIGNED NOT NULL,

    fecha_generacion TIMESTAMP
    DEFAULT CURRENT_TIMESTAMP,

    xml_content LONGTEXT NOT NULL,

    estado_generacion ENUM(
        'exitoso',
        'error'
    ) DEFAULT 'exitoso'
) ENGINE=InnoDB;

-- ======================================================
-- FERIADOS
-- ======================================================

CREATE TABLE feriados_ecuador (
    id_feriado INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    nombre_feriado VARCHAR(100) NOT NULL,

    fecha_inicio DATE NOT NULL,

    fecha_fin DATE NOT NULL,

    id_tarifa INT UNSIGNED NOT NULL,

    CONSTRAINT fk_feriado_tarifa
    FOREIGN KEY (id_tarifa)
    REFERENCES tarifas_iva(id_tarifa)
) ENGINE=InnoDB;

-- ======================================================
-- DATOS INICIALES
-- ======================================================

INSERT INTO cat_tipos_proveedor
(nombre, descripcion)
VALUES
('MICROEMPRESA', 'Proveedor microempresa'),
('AGENTE_RETENCION', 'Agente de retencion'),
('PERSONA_NATURAL', 'Proveedor persona natural'),
('SOCIEDAD', 'Proveedor sociedad');

INSERT INTO retenciones_iva_config
(codigo_sri, id_tipo_proveedor, porcentaje_retencion, descripcion)
VALUES
('RTIVA30', 1, 30.00, 'Retencion IVA 30%'),
('RTIVA70', 2, 70.00, 'Retencion IVA 70%'),
('RTIVA100', 4, 100.00, 'Retencion IVA 100%');

INSERT INTO retenciones_renta_config
(codigo_sri, porcentaje_retencion, concepto, descripcion)
VALUES
('332', 1.00, 'Compra de bienes', 'Retencion 1%'),
('333', 2.00, 'Servicios generales', 'Retencion 2%'),
('334', 8.00, 'Honorarios profesionales', 'Retencion 8%');
