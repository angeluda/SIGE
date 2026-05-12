-- ======================================================
-- 1. PARAMETRIZACIÓN Y CONFIGURACIÓN (CATÁLOGOS)
-- ======================================================

-- Permite parametrización sin cambiar código de los módulos A y C [cite: 56]
CREATE TABLE tarifas_iva (
    id_tarifa INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(10) NOT NULL UNIQUE,
    porcentaje DECIMAL(5,2) NOT NULL,
    descripcion VARCHAR(100),
    fecha_vigencia_desde DATE NOT NULL,
    fecha_vigencia_hasta DATE,
    activo BOOLEAN DEFAULT TRUE
) ENGINE=InnoDB;

-- Configuración de retención de IVA por tipo de proveedor
CREATE TABLE retenciones_iva_config (
    id_ret_iva INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    tipo_proveedor VARCHAR(50) NOT NULL, -- Ej: Microempresa, Agente de Retención
    porcentaje_retencion ENUM('0', '10', '20', '30', '70', '100') NOT NULL,
    descripcion VARCHAR(150)
) ENGINE=InnoDB;

-- ======================================================
-- 2. TRANSACCIONAL Y SOPORTE LEGAL (FORMULARIOS)
-- ======================================================

-- Soporte para Formulario 104 [cite: 56]
CREATE TABLE liquidacion_iva_mensual (
    id_liquidacion INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    periodo DATE NOT NULL, -- Primer día del mes
    iva_cobrado_ventas DECIMAL(10,2) DEFAULT 0.00, -- Viene de Módulo A
    iva_pagado_compras DECIMAL(10,2) DEFAULT 0.00,  -- Viene de Módulo C
    credito_tributario_anterior DECIMAL(10,2) DEFAULT 0.00,
    iva_a_pagar DECIMAL(10,2) DEFAULT 0.00,
    saldo_credito DECIMAL(10,2) DEFAULT 0.00,
    estado ENUM('borrador', 'declarado', 'cerrado') DEFAULT 'borrador'
) ENGINE=InnoDB;

-- Soporte para Formulario 103 y Retenciones en la Fuente [cite: 53]
CREATE TABLE comprobantes_retencion (
    id_comprobante BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    numero VARCHAR(20) NOT NULL UNIQUE,
    fecha DATE NOT NULL,
    proveedor_id INT UNSIGNED NOT NULL, -- FK compartida [cite: 50]
    factura_compra_id INT UNSIGNED NOT NULL, -- FK hacia Módulo C [cite: 53]
    base_imponible_renta DECIMAL(10,2) NOT NULL,
    porcentaje_renta DECIMAL(5,2) NOT NULL,
    valor_retencion_renta DECIMAL(10,2) AS (base_imponible_renta * porcentaje_renta / 100) STORED,
    base_imponible_iva DECIMAL(10,2) NOT NULL,
    porcentaje_iva DECIMAL(5,2) NOT NULL,
    valor_retencion_iva DECIMAL(10,2) AS (base_imponible_iva * porcentaje_iva / 100) STORED,
    xml_generado TEXT,
    numero_autorizacion_simulado VARCHAR(50),
    INDEX idx_ret_compra (factura_compra_id)
) ENGINE=InnoDB;

-- Trazabilidad de generación de documentos electrónicos
CREATE TABLE log_xml_comprobantes (
    id_log BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    tipo ENUM('FACTURA', 'RETENCION') NOT NULL,
    referencia_id BIGINT UNSIGNED NOT NULL, -- id_factura o id_comprobante
    fecha_generacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    xml_content LONGTEXT NOT NULL,
    estado_generacion ENUM('exitoso', 'error') DEFAULT 'exitoso'
) ENGINE=InnoDB;

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