use modulo_d;

-- ======================================================
-- MODULO D - VERSION INTEGRADA Y NORMALIZADA
-- Compatible con Modulo A, B y C
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
    CHECK (porcentaje >= 0
       AND porcentaje <= 100)
) ENGINE=InnoDB;

-- ======================================================
-- DATOS BASE SRI
-- 0%, 5%, 15%
-- ======================================================

INSERT INTO tarifas_iva
(codigo, porcentaje, descripcion, fecha_vigencia_desde)
VALUES
('IVA0', 0.00, 'Tarifa IVA 0%', '2026-01-01'),
('IVA5', 5.00, 'Tarifa IVA 5%', '2026-01-01'),
('IVA15', 15.00, 'Tarifa IVA 15%', '2026-01-01');

-- ======================================================
-- CATALOGO TIPOS DE PROVEEDOR
-- ======================================================

CREATE TABLE cat_tipos_proveedor (
    id_tipo_proveedor TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    nombre VARCHAR(50) NOT NULL UNIQUE,

    descripcion VARCHAR(150),

    activo TINYINT(1) DEFAULT 1
) ENGINE=InnoDB;

-- ======================================================
-- CONFIGURACION RETENCIONES IVA
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

CREATE INDEX idx_ret_iva_tipo
ON retenciones_iva_config(id_tipo_proveedor);

-- ======================================================
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

    anio SMALLINT NOT NULL,

    mes TINYINT NOT NULL,

    iva_cobrado_ventas DECIMAL(12,2) DEFAULT 0.00,

    iva_pagado_compras DECIMAL(12,2) DEFAULT 0.00,

    credito_tributario_anterior DECIMAL(12,2) DEFAULT 0.00,

    iva_a_pagar DECIMAL(12,2) DEFAULT 0.00,

    saldo_credito DECIMAL(12,2) DEFAULT 0.00,

    estado ENUM(
        'borrador',
        'declarado',
        'cerrado'
    ) DEFAULT 'borrador',

    CONSTRAINT uq_periodo
    UNIQUE(anio, mes),

    CONSTRAINT chk_mes
    CHECK (mes >= 1 AND mes <= 12)
) ENGINE=InnoDB;

CREATE INDEX idx_liquidacion_periodo
ON liquidacion_iva_mensual(anio, mes);

-- ======================================================
-- COMPROBANTES DE RETENCION
-- INTEGRACION CON MODULO C
-- ======================================================

CREATE TABLE comprobantes_retencion (
    id_comprobante BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    numero VARCHAR(20) NOT NULL UNIQUE,

    fecha DATE NOT NULL,

    -- ==================================================
    -- REFERENCIAS LOGICAS MODULO C
    -- ==================================================

    -- modulo_c.proveedores.id_proveedor
    ref_mod_c_proveedor_id INT UNSIGNED NOT NULL,

    -- modulo_c.facturas_proveedor.id_factura_prov
    ref_mod_c_factura_id INT UNSIGNED NOT NULL,

    -- ==================================================
    -- DATOS TRIBUTARIOS
    -- ==================================================

    base_imponible_renta DECIMAL(12,2) NOT NULL,

    id_ret_renta INT UNSIGNED NOT NULL,

    valor_retencion_renta DECIMAL(12,2) NOT NULL,

    base_imponible_iva DECIMAL(12,2) NOT NULL,

    id_ret_iva INT UNSIGNED NOT NULL,

    valor_retencion_iva DECIMAL(12,2) NOT NULL,

    subtotal_factura DECIMAL(12,2),

    total_factura DECIMAL(12,2),

    porcentaje_iva_aplicado DECIMAL(5,2),

    codigo_sustento VARCHAR(2),

    -- ==================================================
    -- XML / SRI
    -- ==================================================

    xml_generado LONGTEXT,

    numero_autorizacion_simulado VARCHAR(50),

    estado_sri ENUM(
        'pendiente',
        'autorizado',
        'rechazado'
    ) DEFAULT 'pendiente',

    fecha_generacion TIMESTAMP
    DEFAULT CURRENT_TIMESTAMP,

    -- ==================================================
    -- FK INTERNAS DEL MODULO D
    -- ==================================================

    CONSTRAINT fk_comp_ret_renta
    FOREIGN KEY (id_ret_renta)
    REFERENCES retenciones_renta_config(id_ret_renta),

    CONSTRAINT fk_comp_ret_iva
    FOREIGN KEY (id_ret_iva)
    REFERENCES retenciones_iva_config(id_ret_iva),

    -- ==================================================
    -- VALIDACIONES
    -- ==================================================

    CONSTRAINT chk_base_renta
    CHECK (base_imponible_renta >= 0),

    CONSTRAINT chk_base_iva
    CHECK (base_imponible_iva >= 0),

    CONSTRAINT chk_ret_renta_valor
    CHECK (valor_retencion_renta >= 0),

    CONSTRAINT chk_ret_iva_valor
    CHECK (valor_retencion_iva >= 0),

    CONSTRAINT chk_total_factura
    CHECK (total_factura >= 0)
) ENGINE=InnoDB;

CREATE INDEX idx_retencion_factura
ON comprobantes_retencion(ref_mod_c_factura_id);

CREATE INDEX idx_retencion_proveedor
ON comprobantes_retencion(ref_mod_c_proveedor_id);

CREATE INDEX idx_retencion_fecha
ON comprobantes_retencion(fecha);

CREATE INDEX idx_retencion_estado
ON comprobantes_retencion(estado_sri);

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
-- FERIADOS ECUADOR
-- ======================================================

CREATE TABLE feriados_ecuador (
    id_feriado INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,

    nombre_feriado VARCHAR(100) NOT NULL,

    fecha_inicio DATE NOT NULL,

    fecha_fin DATE NOT NULL,

    descripcion VARCHAR(255),

    aplica_nacional TINYINT(1) DEFAULT 1,

    CONSTRAINT chk_fechas_feriado
    CHECK (fecha_fin >= fecha_inicio)
) ENGINE=InnoDB;

-- ======================================================
-- FERIADOS BASE ECUADOR
-- ======================================================

INSERT INTO feriados_ecuador
(nombre_feriado, fecha_inicio, fecha_fin, descripcion)
VALUES
('Año Nuevo', '2026-01-01', '2026-01-01',
 'Feriado nacional'),

('Carnaval', '2026-02-16', '2026-02-17',
 'Feriado nacional'),

('Viernes Santo', '2026-04-03', '2026-04-03',
 'Feriado religioso'),

('Dia del Trabajo', '2026-05-01', '2026-05-01',
 'Feriado nacional'),

('Primer Grito de Independencia', '2026-08-10', '2026-08-10',
 'Feriado nacional'),

('Independencia de Cuenca', '2026-11-03', '2026-11-03',
 'Feriado local Cuenca'),

('Navidad', '2026-12-25', '2026-12-25',
 'Feriado nacional');

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
