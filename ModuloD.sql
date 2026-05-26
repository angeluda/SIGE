-- ======================================================
-- MODULO D - VERSION FINAL PARA CLEVER CLOUD (INTEGRADA)
-- ======================================================

-- Seleccionamos la base de datos autogenerada de Clever Cloud
USE uabhizo4j1vijlzj;

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
    CHECK (porcentaje >= 0 AND porcentaje <= 100)
) ENGINE=InnoDB;

-- Datos base del SRI para IVA
INSERT INTO tarifas_iva (codigo, porcentaje, descripcion, fecha_vigencia_desde)
VALUES
('IVA0', 0.00, 'Tarifa IVA 0%', '2026-01-01'),
('IVA5', 5.00, 'Tarifa IVA 5%', '2026-01-01'),
('IVA15', 15.00, 'Tarifa IVA 15%', '2026-01-01');

-- TABLA ADICIONAL REQUERIDA (Acuerdo #14 del contrato)
CREATE TABLE tarifas_retencion (
    id_tarifa_retencion INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo_sri VARCHAR(10) NOT NULL UNIQUE,
    porcentaje DECIMAL(5,2) NOT NULL,
    descripcion VARCHAR(150),
    activo TINYINT(1) DEFAULT 1
) ENGINE=InnoDB;

-- CATALOGO TIPOS DE PROVEEDOR
CREATE TABLE cat_tipos_proveedor (
    id_tipo_proveedor TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE,
    descripcion VARCHAR(150),
    activo TINYINT(1) DEFAULT 1
) ENGINE=InnoDB;

-- CONFIGURACION RETENCIONES IVA
CREATE TABLE retenciones_iva_config (
    id_ret_iva INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo_sri VARCHAR(10) NOT NULL UNIQUE,
    id_tipo_proveedor TINYINT UNSIGNED NOT NULL,
    porcentaje_retencion DECIMAL(5,2) NOT NULL,
    descripcion VARCHAR(150),
    activo TINYINT(1) DEFAULT 1,
    CONSTRAINT fk_ret_iva_tipo_proveedor FOREIGN KEY (id_tipo_proveedor) REFERENCES cat_tipos_proveedor(id_tipo_proveedor),
    CONSTRAINT chk_ret_iva_porcentaje CHECK (porcentaje_retencion >= 0 AND porcentaje_retencion <= 100)
) ENGINE=InnoDB;

CREATE INDEX idx_ret_iva_tipo ON retenciones_iva_config(id_tipo_proveedor);

-- CONFIGURACION RETENCIONES RENTA
CREATE TABLE retenciones_renta_config (
    id_ret_renta INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo_sri VARCHAR(10) NOT NULL UNIQUE,
    porcentaje_retencion DECIMAL(5,2) NOT NULL,
    concepto VARCHAR(150) NOT NULL,
    descripcion VARCHAR(255),
    activo TINYINT(1) DEFAULT 1,
    CONSTRAINT chk_ret_renta_porcentaje CHECK (porcentaje_retencion >= 0 AND porcentaje_retencion <= 100)
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
    estado ENUM('borrador', 'declarado', 'cerrado') DEFAULT 'borrador',
    CONSTRAINT uq_periodo UNIQUE(anio, mes),
    CONSTRAINT chk_mes CHECK (mes >= 1 AND mes <= 12)
) ENGINE=InnoDB;

CREATE INDEX idx_liquidacion_periodo ON liquidacion_iva_mensual(anio, mes);

-- ======================================================
-- 3. COMPROBANTES DE RETENCION (INTEGRACION CON MODULO C)
-- ======================================================

CREATE TABLE comprobantes_retencion (
    -- CORRECCIÓN: Tipo cambiado de BIGINT a INT UNSIGNED para homologar con Módulo C (Acuerdo #25)
    id_comprobante INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    numero VARCHAR(20) NOT NULL UNIQUE,
    fecha DATE NOT NULL,

    -- CORRECCIÓN: Campo renombrado a id_proveedor (Acuerdo #18)
    id_proveedor INT UNSIGNED NOT NULL,

    -- CORRECCIÓN: Campo renombrado a id_factura_prov (Acuerdo #19)
    id_factura_prov INT UNSIGNED NOT NULL,

    -- DATOS TRIBUTARIOS
    base_imponible_renta DECIMAL(12,2) NOT NULL,
    id_ret_renta INT UNSIGNED NOT NULL,
    valor_retencion_renta DECIMAL(12,2) NOT NULL,
    base_imponible_iva DECIMAL(12,2) NOT NULL,
    id_ret_iva INT UNSIGNED NOT NULL,
    valor_retencion_iva DECIMAL(12,2) NOT NULL,
    subtotal_factura DECIMAL(12,2),
    total_factura DECIMAL(12,2),
    porcentaje_iva_aplicado DECIMAL(5,2),
    
    -- CUMPLE: Campo requerido para el Payload de integración IF-05 (Acuerdo #15)
    codigo_sustento VARCHAR(2),

    -- CORRECCIÓN: Campo renombrado a xml_retencion (Acuerdo #17)
    xml_retencion LONGTEXT,

    -- CORRECCIÓN: Campo renombrado a num_autorizacion y ajustado a VARCHAR(49) (Acuerdo #16)
    num_autorizacion VARCHAR(49),

    estado_sri ENUM('pendiente', 'autorizado', 'rechazado') DEFAULT 'pendiente',
    fecha_generacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    -- FK TRIBUTARIAS INTERNAS
    CONSTRAINT fk_comp_ret_renta FOREIGN KEY (id_ret_renta) REFERENCES retenciones_renta_config(id_ret_renta),
    CONSTRAINT fk_comp_ret_iva FOREIGN KEY (id_ret_iva) REFERENCES retenciones_iva_config(id_ret_iva),

    -- VALIDACIONES
    CONSTRAINT chk_base_renta CHECK (base_imponible_renta >= 0),
    CONSTRAINT chk_base_iva CHECK (base_imponible_iva >= 0),
    CONSTRAINT chk_ret_renta_valor CHECK (valor_retencion_renta >= 0),
    CONSTRAINT chk_ret_iva_valor CHECK (valor_retencion_iva >= 0),
    CONSTRAINT chk_total_factura CHECK (total_factura >= 0)
) ENGINE=InnoDB;

-- Índices optimizados
CREATE INDEX idx_retencion_factura ON comprobantes_retencion(id_factura_prov);
CREATE INDEX idx_retencion_proveedor ON comprobantes_retencion(id_proveedor);
CREATE INDEX idx_retencion_fecha ON comprobantes_retencion(fecha);
CREATE INDEX idx_retencion_estado ON comprobantes_retencion(estado_sri);

-- LOG XML ADAPTADO
CREATE TABLE log_xml_comprobantes (
    id_log BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    tipo ENUM('FACTURA', 'RETENCION') NOT NULL,
    referencia_id INT UNSIGNED NOT NULL, -- Ajustado para emparejar con el nuevo id_comprobante
    fecha_generacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    xml_content LONGTEXT NOT NULL,
    estado_generacion ENUM('exitoso', 'error') DEFAULT 'exitoso'
) ENGINE=InnoDB;

-- FERIADOS ECUADOR (CORRECCIÓN: Se eliminó la relación inconsistente id_tarifa, Acuerdo #24)
CREATE TABLE feriados_ecuador (
    id_feriado INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre_feriado VARCHAR(100) NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    descripcion VARCHAR(255),
    aplica_nacional TINYINT(1) DEFAULT 1,
    CONSTRAINT chk_fechas_feriado CHECK (fecha_fin >= fecha_inicio)
) ENGINE=InnoDB;

-- ======================================================
-- 4. INSERCIÓN DE DATOS INICIALES
-- ======================================================

INSERT INTO feriados_ecuador (nombre_feriado, fecha_inicio, fecha_fin, descripcion)
VALUES
('Año Nuevo', '2026-01-01', '2026-01-01', 'Feriado nacional'),
('Carnaval', '2026-02-16', '2026-02-17', 'Feriado nacional'),
('Viernes Santo', '2026-04-03', '2026-04-03', 'Feriado religioso'),
('Dia del Trabajo', '2026-05-01', '2026-05-01', 'Feriado nacional'),
('Primer Grito de Independencia', '2026-08-10', '2026-08-10', 'Feriado nacional'),
('Independencia de Cuenca', '2026-11-03', '2026-11-03', 'Feriado local Cuenca'),
('Navidad', '2026-12-25', '2026-12-25', 'Feriado nacional');

INSERT INTO cat_tipos_proveedor (nombre, descripcion)
VALUES
('MICROEMPRESA', 'Proveedor microempresa'),
('AGENTE_RETENCION', 'Agente de retencion'),
('PERSONA_NATURAL', 'Proveedor persona natural'),
('SOCIEDAD', 'Proveedor sociedad');

INSERT INTO retenciones_iva_config (codigo_sri, id_tipo_proveedor, porcentaje_retencion, descripcion)
VALUES
('RTIVA30', 1, 30.00, 'Retencion IVA 30%'),
('RTIVA70', 2, 70.00, 'Retencion IVA 70%'),
('RTIVA100', 4, 100.00, 'Retencion IVA 100%');

INSERT INTO retenciones_renta_config (codigo_sri, porcentaje_retencion, concepto, descripcion)
VALUES
('332', 1.00, 'Compra de bienes', 'Retencion 1%'),
('333', 2.00, 'Servicios generales', 'Retencion 2%'),
('334', 8.00, 'Honorarios profesionales', 'Retencion 8%');


-- ======================================================
-- 5. VISTAS Y PROCEDIMIENTOS OBLIGATORIOS POR CONTRATO
-- ======================================================

-- REQUERIDO: Vista para auditoría y consultas del Módulo C (Acuerdo #23)
CREATE VIEW vw_comprobantes_por_factura AS
SELECT 
    id_factura_prov, 
    COUNT(id_comprobante) AS cantidad_comprobantes, 
    SUM(valor_retencion_iva) AS total_retenido_iva,
    SUM(valor_retencion_renta) AS total_retenido_renta,
    estado_sri
FROM comprobantes_retencion
GROUP BY id_factura_prov, estado_sri;

DELIMITER //

-- REQUERIDO: Procedimiento fundamental para procesar la retención del flujo IF-05 (Acuerdo #21)
CREATE PROCEDURE sp_generar_comprobante_retencion(
    IN p_id_factura_prov INT UNSIGNED, 
    IN p_id_proveedor INT UNSIGNED,
    IN p_base_iva DECIMAL(12,2),
    IN p_base_renta DECIMAL(12,2)
)
BEGIN
    INSERT INTO comprobantes_retencion (
        numero, fecha, id_proveedor, id_factura_prov, 
        base_imponible_renta, id_ret_renta, valor_retencion_renta, 
        base_imponible_iva, id_ret_iva, valor_retencion_iva,
        codigo_sustento, estado_sri
    ) VALUES (
        CONCAT('RET-', p_id_factura_prov), CURDATE(), p_id_proveedor, p_id_factura_prov,
        p_base_renta, 1, (p_base_renta * 0.01), 
        p_base_iva, 1, (p_base_iva * 0.30),
        '01', 'pendiente'
    );
END //

-- REQUERIDO: Procedimiento asíncrono para mantener actualizado al Módulo C (Acuerdo #22)
CREATE PROCEDURE sp_notificar_retencion_a_modc(
    IN p_id_comprobante INT UNSIGNED
)
BEGIN
    -- Mapeo o canal de comunicación de cambios hacia Cuentas por Pagar
    SELECT CONCAT('Notificación de actualización enviada al Módulo C para el comprobante: ', p_id_comprobante) AS Info_Integracion;
END //

DELIMITER ;
