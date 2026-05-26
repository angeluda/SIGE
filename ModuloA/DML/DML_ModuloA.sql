DELIMITER $$

-- TABLAS CATÁLOGO
CREATE PROCEDURE sp_cat_listar_tipos_cliente()
BEGIN
    SELECT id, nombre FROM cat_tipos_cliente ORDER BY nombre;
END$$

CREATE PROCEDURE sp_cat_listar_estados_facturas()
BEGIN
    SELECT id, nombre FROM cat_estados_facturas ORDER BY nombre;
END$$

CREATE PROCEDURE sp_cat_listar_estados_cxc()
BEGIN
    SELECT id, nombre FROM cat_estados_cxc ORDER BY nombre;
END$$

CREATE PROCEDURE sp_cat_listar_formas_pago()
BEGIN
    SELECT id, nombre FROM cat_formas_pago ORDER BY nombre;
END$$

-- CLIENTES — PERSONA NATURAL
CREATE PROCEDURE sp_cliente_natural_crear(
    IN  p_direccion    VARCHAR(255),
    IN  p_telefono     VARCHAR(20),
    IN  p_correo       VARCHAR(100),
    IN  p_dias_credito INT UNSIGNED,
    IN  p_cedula       VARCHAR(10),
    IN  p_nombres      VARCHAR(100),
    IN  p_apellidos    VARCHAR(100),
    OUT p_cliente_id   INT UNSIGNED
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN ROLLBACK; RESIGNAL; END;

    START TRANSACTION;

    INSERT INTO clientes (tipo_cliente_id, direccion, telefono, correo_electronico, dias_credito, estado)
    VALUES (1, p_direccion, p_telefono, p_correo, p_dias_credito, 'ACTIVO');

    SET p_cliente_id = LAST_INSERT_ID();

    INSERT INTO personas_naturales (cliente_id, cedula, nombres, apellidos)
    VALUES (p_cliente_id, p_cedula, p_nombres, p_apellidos);

    COMMIT;
END$$

CREATE PROCEDURE sp_cliente_natural_actualizar(
    IN p_cliente_id   INT UNSIGNED,
    IN p_direccion    VARCHAR(255),
    IN p_telefono     VARCHAR(20),
    IN p_correo       VARCHAR(100),
    IN p_dias_credito INT UNSIGNED,
    IN p_nombres      VARCHAR(100),
    IN p_apellidos    VARCHAR(100)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN ROLLBACK; RESIGNAL; END;

    START TRANSACTION;

    UPDATE clientes
    SET direccion = p_direccion, telefono = p_telefono,
        correo_electronico = p_correo, dias_credito = p_dias_credito
    WHERE id = p_cliente_id AND tipo_cliente_id = 1;

    UPDATE personas_naturales
    SET nombres = p_nombres, apellidos = p_apellidos
    WHERE cliente_id = p_cliente_id;

    COMMIT;
END$$

CREATE PROCEDURE sp_cliente_natural_buscar_por_id(
    IN p_cliente_id INT UNSIGNED
)
BEGIN
    SELECT
        c.id, c.direccion, c.telefono, c.correo_electronico,
        c.dias_credito, c.estado, pn.cedula, pn.nombres, pn.apellidos
    FROM clientes c
    INNER JOIN personas_naturales pn ON pn.cliente_id = c.id
    WHERE c.id = p_cliente_id;
END$$

-- CLIENTES — PERSONA JURÍDICA
CREATE PROCEDURE sp_cliente_juridico_crear(
    IN  p_direccion     VARCHAR(255),
    IN  p_telefono      VARCHAR(20),
    IN  p_correo        VARCHAR(100),
    IN  p_dias_credito  INT UNSIGNED,
    IN  p_ruc           VARCHAR(13),
    IN  p_razon_social  VARCHAR(150),
    IN  p_representante VARCHAR(150),
    OUT p_cliente_id    INT UNSIGNED
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN ROLLBACK; RESIGNAL; END;

    START TRANSACTION;

    INSERT INTO clientes (tipo_cliente_id, direccion, telefono, correo_electronico, dias_credito, estado)
    VALUES (2, p_direccion, p_telefono, p_correo, p_dias_credito, 'ACTIVO');

    SET p_cliente_id = LAST_INSERT_ID();

    INSERT INTO personas_juridicas (cliente_id, ruc, razon_social, representante_legal)
    VALUES (p_cliente_id, p_ruc, p_razon_social, p_representante);

    COMMIT;
END$$

CREATE PROCEDURE sp_cliente_juridico_actualizar(
    IN p_cliente_id    INT UNSIGNED,
    IN p_direccion     VARCHAR(255),
    IN p_telefono      VARCHAR(20),
    IN p_correo        VARCHAR(100),
    IN p_dias_credito  INT UNSIGNED,
    IN p_razon_social  VARCHAR(150),
    IN p_representante VARCHAR(150)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN ROLLBACK; RESIGNAL; END;

    START TRANSACTION;

    UPDATE clientes
    SET direccion = p_direccion, telefono = p_telefono,
        correo_electronico = p_correo, dias_credito = p_dias_credito
    WHERE id = p_cliente_id AND tipo_cliente_id = 2;

    UPDATE personas_juridicas
    SET razon_social = p_razon_social, representante_legal = p_representante
    WHERE cliente_id = p_cliente_id;

    COMMIT;
END$$

CREATE PROCEDURE sp_cliente_juridico_buscar_por_id(
    IN p_cliente_id INT UNSIGNED
)
BEGIN
    SELECT
        c.id, c.direccion, c.telefono, c.correo_electronico,
        c.dias_credito, c.estado, pj.ruc, pj.razon_social, pj.representante_legal
    FROM clientes c
    INNER JOIN personas_juridicas pj ON pj.cliente_id = c.id
    WHERE c.id = p_cliente_id;
END$$

-- CLIENTES — OPERACIONES COMUNES
CREATE PROCEDURE sp_cliente_desactivar(
    IN p_cliente_id INT UNSIGNED
)
BEGIN
    UPDATE clientes
    SET estado = 'INACTIVO'
    WHERE id = p_cliente_id;
END$$

CREATE PROCEDURE sp_clientes_listar(
    IN p_tipo     TINYINT UNSIGNED,
    IN p_estado   VARCHAR(10),
    IN p_busqueda VARCHAR(150)
)
BEGIN
    SELECT
        c.id, tc.nombre AS tipo_cliente, c.estado, c.direccion,
        c.telefono, c.correo_electronico, c.dias_credito,
        COALESCE(pn.cedula,   pj.ruc) AS identificacion,
        COALESCE(CONCAT(pn.nombres, ' ', pn.apellidos), pj.razon_social) AS nombre_completo
    FROM clientes c
    INNER JOIN cat_tipos_cliente tc    ON tc.id = c.tipo_cliente_id
    LEFT  JOIN personas_naturales pn   ON pn.cliente_id = c.id
    LEFT  JOIN personas_juridicas pj   ON pj.cliente_id = c.id
    WHERE (p_tipo    IS NULL OR c.tipo_cliente_id = p_tipo)
      AND (p_estado  IS NULL OR c.estado          = p_estado)
      AND (p_busqueda IS NULL
           OR CONCAT(pn.nombres,' ',pn.apellidos) LIKE CONCAT('%',p_busqueda,'%')
           OR pj.razon_social                      LIKE CONCAT('%',p_busqueda,'%'))
    ORDER BY nombre_completo;
END$$

-- VENDEDORES
CREATE PROCEDURE sp_vendedor_crear(
    IN  p_cedula              VARCHAR(10),
    IN  p_nombres             VARCHAR(100),
    IN  p_apellidos           VARCHAR(100),
    IN  p_zona                VARCHAR(50),
    IN  p_porcentaje_comision DECIMAL(5,2),
    OUT p_vendedor_id         INT UNSIGNED
)
BEGIN
    INSERT INTO vendedores (cedula, nombres, apellidos, zona, porcentaje_comision, estado)
    VALUES (p_cedula, p_nombres, p_apellidos, p_zona, p_porcentaje_comision, 'ACTIVO');

    SET p_vendedor_id = LAST_INSERT_ID();
END$$

CREATE PROCEDURE sp_vendedor_actualizar(
    IN p_vendedor_id         INT UNSIGNED,
    IN p_nombres             VARCHAR(100),
    IN p_apellidos           VARCHAR(100),
    IN p_zona                VARCHAR(50),
    IN p_porcentaje_comision DECIMAL(5,2)
)
BEGIN
    UPDATE vendedores
    SET nombres = p_nombres, apellidos = p_apellidos,
        zona = p_zona, porcentaje_comision = p_porcentaje_comision
    WHERE id = p_vendedor_id;
END$$

CREATE PROCEDURE sp_vendedor_desactivar(
    IN p_vendedor_id INT UNSIGNED
)
BEGIN
    UPDATE vendedores
    SET estado = 'INACTIVO'
    WHERE id = p_vendedor_id;
END$$

CREATE PROCEDURE sp_vendedor_buscar_por_id(
    IN p_vendedor_id INT UNSIGNED
)
BEGIN
    SELECT id, cedula, nombres, apellidos, zona, porcentaje_comision, estado
    FROM vendedores WHERE id = p_vendedor_id;
END$$

CREATE PROCEDURE sp_vendedores_listar(
    IN p_zona   VARCHAR(50),
    IN p_estado VARCHAR(10)
)
BEGIN
    SELECT id, cedula, nombres, apellidos, zona, porcentaje_comision, estado
    FROM vendedores
    WHERE (p_zona   IS NULL OR zona   = p_zona)
      AND (p_estado IS NULL OR estado = p_estado)
    ORDER BY apellidos, nombres;
END$$

-- FACTURAS (MOD B Y D)
CREATE PROCEDURE sp_factura_crear(
    IN  p_numero_factura VARCHAR(20),
    IN  p_fecha_emision  DATE,
    IN  p_cliente_id     INT UNSIGNED,
    IN  p_vendedor_id    INT UNSIGNED,
    OUT p_factura_id     INT UNSIGNED
)
BEGIN
    DECLARE v_total        DECIMAL(10,2) DEFAULT 0.00;
    DECLARE v_dias_credito INT UNSIGNED;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN ROLLBACK; RESIGNAL; END;

    -- Adaptado a los nuevos campos de detalle_factura
    CREATE TEMPORARY TABLE IF NOT EXISTS temp_detalles (
        product_id     INT UNSIGNED    NOT NULL,
        id_tarifa       INT UNSIGNED    NOT NULL,
        cantidad        INT UNSIGNED    NOT NULL,
        precio_unitario DECIMAL(10,2)   NOT NULL,
        descuento       DECIMAL(10,2)   NOT NULL DEFAULT 0.00
    );

    START TRANSACTION;

    SELECT SUM((precio_unitario * cantidad) - descuento) INTO v_total
    FROM temp_detalles;

    IF v_total IS NULL OR v_total = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No hay productos en la tabla temporal.';
    END IF;

    INSERT INTO facturas (numero_factura, fecha_emision, total, cliente_id, vendedor_id, estado_id)
    VALUES (p_numero_factura, p_fecha_emision, v_total, p_cliente_id, p_vendedor_id, 1);

    SET p_factura_id = LAST_INSERT_ID();

    INSERT INTO detalle_factura (factura_id, product_id, id_tarifa, cantidad, precio_unitario, descuento)
    SELECT p_factura_id, product_id, id_tarifa, cantidad, precio_unitario, descuento
    FROM temp_detalles;

    SELECT dias_credito INTO v_dias_credito FROM clientes WHERE id = p_cliente_id;

    IF v_dias_credito > 0 THEN
        INSERT INTO cuentas_por_cobrar (factura_id, fecha_vencimiento, saldo_pendiente, estado_id)
        VALUES (
            p_factura_id,
            DATE_ADD(p_fecha_emision, INTERVAL v_dias_credito DAY),
            v_total,
            1
        );
    END IF;

    COMMIT;

    TRUNCATE TABLE temp_detalles;
END$$

CREATE PROCEDURE sp_factura_anular(
    IN p_factura_id INT UNSIGNED
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN ROLLBACK; RESIGNAL; END;

    START TRANSACTION;

    IF EXISTS (
        SELECT 1 FROM pagos_cliente
        WHERE factura_id = p_factura_id AND anulado = 0
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No se puede anular una factura con pagos vigentes registrados.';
    END IF;

    UPDATE facturas SET estado_id = 4 WHERE id = p_factura_id;
    UPDATE cuentas_por_cobrar SET estado_id = 3 WHERE factura_id = p_factura_id;

    COMMIT;
END$$

CREATE PROCEDURE sp_factura_buscar_por_id(
    IN p_factura_id INT UNSIGNED
)
BEGIN
    -- Cabecera
    SELECT
        f.id, f.numero_factura, f.fecha_emision, f.total,
        ef.nombre AS estado,
        f.cliente_id,
        COALESCE(CONCAT(pn.nombres,' ',pn.apellidos), pj.razon_social) AS cliente,
        f.vendedor_id,
        CONCAT(v.nombres,' ',v.apellidos) AS vendedor
    FROM facturas f
    INNER JOIN cat_estados_facturas ef ON ef.id = f.estado_id
    INNER JOIN clientes c              ON c.id  = f.cliente_id
    LEFT  JOIN personas_naturales pn   ON pn.cliente_id = c.id
    LEFT  JOIN personas_juridicas pj   ON pj.cliente_id = c.id
    INNER JOIN vendedores v            ON v.id  = f.vendedor_id
    WHERE f.id = p_factura_id;

    -- Detalles actualizados a la nueva estructura
    SELECT
        d.id, d.product_id, d.id_tarifa, d.cantidad, d.precio_unitario, d.descuento,
        (d.precio_unitario * d.cantidad) - d.descuento AS subtotal
    FROM detalle_factura d
    WHERE d.factura_id = p_factura_id;
END$$

CREATE PROCEDURE sp_facturas_listar(
    IN p_cliente_id  INT UNSIGNED,
    IN p_vendedor_id INT UNSIGNED,
    IN p_estado_id   TINYINT UNSIGNED,
    IN p_fecha_desde DATE,
    IN p_fecha_hasta DATE
)
BEGIN
    SELECT
        f.id, f.numero_factura, f.fecha_emision, f.total,
        ef.nombre AS estado,
        COALESCE(CONCAT(pn.nombres,' ',pn.apellidos), pj.razon_social) AS cliente,
        CONCAT(v.nombres,' ',v.apellidos) AS vendedor
    FROM facturas f
    INNER JOIN cat_estados_facturas ef ON ef.id = f.estado_id
    INNER JOIN clientes c              ON c.id  = f.cliente_id
    LEFT  JOIN personas_naturales pn   ON pn.cliente_id = c.id
    LEFT  JOIN personas_juridicas pj   ON pj.cliente_id = c.id
    INNER JOIN vendedores v            ON v.id  = f.vendedor_id
    WHERE (p_cliente_id  IS NULL OR f.cliente_id  = p_cliente_id)
      AND (p_vendedor_id IS NULL OR f.vendedor_id = p_vendedor_id)
      AND (p_estado_id   IS NULL OR f.estado_id   = p_estado_id)
      AND (p_fecha_desde IS NULL OR f.fecha_emision >= p_fecha_desde)
      AND (p_fecha_hasta IS NULL OR f.fecha_emision <= p_fecha_hasta)
    ORDER BY f.fecha_emision DESC;
END$$

-- CUENTAS POR COBRAR
CREATE PROCEDURE sp_cxc_buscar_por_factura(IN p_factura_id INT UNSIGNED)
BEGIN
    SELECT
        cxc.id, cxc.factura_id, f.numero_factura,
        cxc.fecha_vencimiento, cxc.saldo_pendiente, e.nombre AS estado
    FROM cuentas_por_cobrar cxc
    INNER JOIN facturas f        ON f.id  = cxc.factura_id
    INNER JOIN cat_estados_cxc e ON e.id  = cxc.estado_id
    WHERE cxc.factura_id = p_factura_id;
END$$

CREATE PROCEDURE sp_cxc_listar(
    IN p_estado_id   TINYINT UNSIGNED,
    IN p_cliente_id  INT UNSIGNED,
    IN p_fecha_hasta DATE
)
BEGIN
    SELECT
        cxc.id, cxc.factura_id, f.numero_factura, f.fecha_emision,
        cxc.fecha_vencimiento, cxc.saldo_pendiente, e.nombre AS estado,
        COALESCE(CONCAT(pn.nombres,' ',pn.apellidos), pj.razon_social) AS cliente
    FROM cuentas_por_cobrar cxc
    INNER JOIN facturas f              ON f.id  = cxc.factura_id
    INNER JOIN cat_estados_cxc e       ON e.id  = cxc.estado_id
    INNER JOIN clientes c              ON c.id  = f.cliente_id
    LEFT  JOIN personas_naturales pn   ON pn.cliente_id = c.id
    LEFT  JOIN personas_juridicas pj   ON pj.cliente_id = c.id
    WHERE (p_estado_id  IS NULL OR cxc.estado_id        = p_estado_id)
      AND (p_cliente_id IS NULL OR f.cliente_id         = p_cliente_id)
      AND (p_fecha_hasta IS NULL OR cxc.fecha_vencimiento <= p_fecha_hasta)
    ORDER BY cxc.fecha_vencimiento ASC;
END$$

CREATE PROCEDURE sp_cxc_marcar_en_mora()
BEGIN
    UPDATE cuentas_por_cobrar
    SET estado_id = 2
    WHERE estado_id = 1
      AND fecha_vencimiento < CURDATE()
      AND saldo_pendiente   > 0;
END$$

-- PAGOS
CREATE PROCEDURE sp_pago_registrar(
    IN  p_factura_id    INT UNSIGNED,
    IN  p_monto         DECIMAL(10,2),
    IN  p_forma_pago_id TINYINT UNSIGNED,
    OUT p_pago_id       INT UNSIGNED
)
BEGIN
    DECLARE v_saldo_actual DECIMAL(10,2);
    DECLARE v_nuevo_saldo  DECIMAL(10,2);
    DECLARE v_cxc_id       INT UNSIGNED;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN ROLLBACK; RESIGNAL; END;

    START TRANSACTION;

    IF NOT EXISTS (SELECT 1 FROM facturas WHERE id = p_factura_id AND estado_id <> 4) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Factura no existe o está anulada.';
    END IF;

    SELECT id, saldo_pendiente INTO v_cxc_id, v_saldo_actual
    FROM cuentas_por_cobrar WHERE factura_id = p_factura_id;

    IF v_saldo_actual IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No existe cuenta por cobrar para esta factura.';
    END IF;

    IF p_monto > v_saldo_actual THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El monto del pago supera el saldo pendiente.';
    END IF;

    INSERT INTO pagos_cliente (factura_id, monto, forma_pago_id, anulado)
    VALUES (p_factura_id, p_monto, p_forma_pago_id, 0);

    SET p_pago_id = LAST_INSERT_ID();
    SET v_nuevo_saldo = v_saldo_actual - p_monto;

    UPDATE cuentas_por_cobrar
    SET saldo_pendiente = v_nuevo_saldo,
        estado_id = CASE WHEN v_nuevo_saldo = 0 THEN 3 ELSE estado_id END
    WHERE id = v_cxc_id;

    IF v_nuevo_saldo = 0 THEN
        UPDATE facturas SET estado_id = 3 WHERE id = p_factura_id;
    END IF;

    COMMIT;
END$$

CREATE PROCEDURE sp_pagos_listar_por_factura(IN p_factura_id INT UNSIGNED)
BEGIN
    SELECT p.id, p.fecha, p.monto, fp.nombre AS forma_pago, p.anulado
    FROM pagos_cliente p
    INNER JOIN cat_formas_pago fp ON fp.id = p.forma_pago_id
    WHERE p.factura_id = p_factura_id
    ORDER BY p.fecha DESC;
END$$

CREATE PROCEDURE sp_pago_anular(
    IN p_pago_id INT UNSIGNED
)
BEGIN
    DECLARE v_factura_id   INT UNSIGNED;
    DECLARE v_monto        DECIMAL(10,2);
    DECLARE v_anulado      TINYINT(1);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN ROLLBACK; RESIGNAL; END;

    START TRANSACTION;

    SELECT factura_id, monto, anulado
    INTO v_factura_id, v_monto, v_anulado
    FROM pagos_cliente WHERE id = p_pago_id;

    IF v_factura_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pago no encontrado.';
    END IF;

    IF v_anulado = 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El pago ya fue anulado anteriormente.';
    END IF;

    UPDATE pagos_cliente SET anulado = 1 WHERE id = p_pago_id;

    UPDATE cuentas_por_cobrar
    SET saldo_pendiente = saldo_pendiente + v_monto,
        estado_id = CASE
            WHEN fecha_vencimiento < CURDATE() THEN 2  -- EN_MORA
            ELSE 1                                      -- AL_DIA
        END
    WHERE factura_id = v_factura_id;

    UPDATE facturas
    SET estado_id = 1
    WHERE id = v_factura_id AND estado_id = 3;

    COMMIT;
END$$

-- TRIGGERS Y VISTAS
CREATE TRIGGER trg_pago_actualizar_cxc
AFTER INSERT ON pagos_cliente
FOR EACH ROW
BEGIN
    DECLARE v_nuevo_saldo DECIMAL(10,2);
    DECLARE v_cxc_id      INT UNSIGNED;

    IF NEW.anulado = 0 THEN
        SELECT id INTO v_cxc_id FROM cuentas_por_cobrar WHERE factura_id = NEW.factura_id;

        UPDATE cuentas_por_cobrar
        SET saldo_pendiente = saldo_pendiente - NEW.monto,
            estado_id = CASE
                WHEN (saldo_pendiente - NEW.monto) <= 0 THEN 3  -- CANCELADA
                ELSE estado_id
            END
        WHERE id = v_cxc_id;

        SELECT saldo_pendiente INTO v_nuevo_saldo FROM cuentas_por_cobrar WHERE id = v_cxc_id;

        IF v_nuevo_saldo <= 0 THEN
            UPDATE facturas SET estado_id = 3 WHERE id = NEW.factura_id;
        END IF;
    END IF;
END$$

CREATE VIEW v_facturas_por_cliente AS
SELECT
    f.id                                                        AS factura_id,
    f.numero_factura,
    f.fecha_emision,
    f.total,
    ef.nombre                                                   AS estado,
    c.id                                                        AS cliente_id,
    COALESCE(CONCAT(pn.nombres, ' ', pn.apellidos), pj.razon_social) AS cliente,
    COALESCE(pn.cedula, pj.ruc)                                 AS identificacion,
    c.dias_credito,
    CONCAT(v.nombres, ' ', v.apellidos)                         AS vendedor,
    cxc.saldo_pendiente,
    cxc.fecha_vencimiento
FROM facturas f
INNER JOIN cat_estados_facturas ef  ON ef.id = f.estado_id
INNER JOIN clientes c               ON c.id  = f.cliente_id
LEFT  JOIN personas_naturales pn    ON pn.cliente_id = c.id
LEFT  JOIN personas_juridicas pj    ON pj.cliente_id = c.id
INNER JOIN vendedores v             ON v.id  = f.vendedor_id
LEFT  JOIN cuentas_por_cobrar cxc   ON cxc.factura_id = f.id$$

DELIMITER ;