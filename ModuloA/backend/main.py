from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import mysql.connector

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─────────────────────────────────────────────
# Modelos
# ─────────────────────────────────────────────

class Cliente(BaseModel):
    tipo_cliente_id: int
    identificacion: str
    nombre: str
    email: str
    direccion: str

class DetalleFactura(BaseModel):
    product_id: int
    id_tarifa: int
    cantidad: int
    precio_unitario: float
    descuento: float = 0.0

class Factura(BaseModel):
    numero_factura: str
    cliente_id: int
    vendedor_id: int
    detalles: list[DetalleFactura]

class Pago(BaseModel):
    factura_id: int
    monto: float
    forma_pago_id: int

# ─────────────────────────────────────────────
# Conexión
# ─────────────────────────────────────────────

def get_db_connection():
    return mysql.connector.connect(
        host="localhost",
        user="root",
        password="Eimi@12345",
        database="modulo_a"
    )

# ─────────────────────────────────────────────
# CLIENTES
# ─────────────────────────────────────────────

@app.get("/api/clientes")
def get_clientes():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("""
        SELECT c.id,
            COALESCE(pn.cedula, pj.ruc) AS identificacion,
            COALESCE(CONCAT(pn.nombres, ' ', pn.apellidos), pj.razon_social) AS nombre,
            c.correo_electronico AS email,
            c.direccion
        FROM clientes c
        LEFT JOIN personas_naturales pn ON c.id = pn.cliente_id
        LEFT JOIN personas_juridicas pj ON c.id = pj.cliente_id
        WHERE c.estado = 'ACTIVO'
    """)
    clientes = cursor.fetchall()
    cursor.close()
    conn.close()
    return clientes

@app.post("/api/clientes")
def create_cliente(cliente: Cliente):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "INSERT INTO clientes (tipo_cliente_id, direccion, correo_electronico, dias_credito) VALUES (%s, %s, %s, 0)",
            (cliente.tipo_cliente_id, cliente.direccion, cliente.email)
        )
        cliente_id = cursor.lastrowid

        if cliente.tipo_cliente_id == 1:
            partes = cliente.nombre.strip().split(' ', 1)
            nombres = partes[0]
            apellidos = partes[1] if len(partes) > 1 else ''
            cursor.execute(
                "INSERT INTO personas_naturales (cliente_id, cedula, nombres, apellidos) VALUES (%s, %s, %s, %s)",
                (cliente_id, cliente.identificacion, nombres, apellidos)
            )
        else:
            cursor.execute(
                "INSERT INTO personas_juridicas (cliente_id, ruc, razon_social) VALUES (%s, %s, %s)",
                (cliente_id, cliente.identificacion, cliente.nombre)
            )

        conn.commit()
        return {"success": True, "id": cliente_id}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cursor.close()
        conn.close()

# ─────────────────────────────────────────────
# FACTURAS
# ─────────────────────────────────────────────

@app.get("/api/facturas")
def get_facturas():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("""
        SELECT f.id, f.numero_factura,
               DATE_FORMAT(f.fecha_emision, '%Y-%m-%d') AS fecha,
               f.total, f.cliente_id, ef.nombre AS estado,
               COALESCE(CONCAT(pn.nombres, ' ', pn.apellidos), pj.razon_social) AS cliente_nombre
        FROM facturas f
        JOIN cat_estados_facturas ef ON f.estado_id = ef.id
        LEFT JOIN personas_naturales pn ON f.cliente_id = pn.cliente_id
        LEFT JOIN personas_juridicas pj ON f.cliente_id = pj.cliente_id
        ORDER BY f.id DESC
    """)
    facturas = cursor.fetchall()
    cursor.close()
    conn.close()
    return facturas

@app.post("/api/facturas")
def create_factura(factura: Factura):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        # Calcular total usando tarifa IVA de modulo_d
        total = 0.0
        for d in factura.detalles:
            subtotal = (d.precio_unitario * d.cantidad) - d.descuento
            cursor.execute(
                "SELECT porcentaje FROM modulo_d.tarifas_iva WHERE id_tarifa = %s AND activo = 1",
                (d.id_tarifa,)
            )
            row = cursor.fetchone()
            porcentaje = float(row[0]) / 100 if row else 0.15
            total += subtotal * (1 + porcentaje)

        from datetime import date
        cursor.execute(
            """INSERT INTO facturas (numero_factura, fecha_emision, total, cliente_id, vendedor_id, estado_id)
               VALUES (%s, %s, %s, %s, %s, 1)""",
            (factura.numero_factura, date.today(), round(total, 2), factura.cliente_id, factura.vendedor_id)
        )
        factura_id = cursor.lastrowid

        for d in factura.detalles:
            cursor.execute(
                """INSERT INTO detalle_factura (factura_id, product_id, id_tarifa, cantidad, precio_unitario, descuento)
                   VALUES (%s, %s, %s, %s, %s, %s)""",
                (factura_id, d.product_id, d.id_tarifa, d.cantidad, d.precio_unitario, d.descuento)
            )
            # Descontar stock via procedimiento oficial del Módulo B
            # sp_registrar_salida_inventario(product_id, bodega_id, cantidad, referencia)
            cursor.callproc("modulo_b.sp_registrar_salida_inventario",
                            [d.product_id, 1, d.cantidad, factura.numero_factura])

        # Crear cuenta por cobrar si el cliente tiene crédito
        cursor.execute("SELECT dias_credito FROM clientes WHERE id = %s", (factura.cliente_id,))
        row = cursor.fetchone()
        dias = row[0] if row else 0
        if dias and dias > 0:
            cursor.execute(
                """INSERT INTO cuentas_por_cobrar (factura_id, fecha_vencimiento, saldo_pendiente, estado_id)
                   VALUES (%s, DATE_ADD(CURDATE(), INTERVAL %s DAY), %s, 1)""",
                (factura_id, dias, round(total, 2))
            )

        conn.commit()
        return {"success": True, "id": factura_id, "total": round(total, 2)}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cursor.close()
        conn.close()

@app.get("/api/facturas/pendientes")
def get_facturas_pendientes():
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("""
        SELECT f.id, f.numero_factura,
               COALESCE(CONCAT(pn.nombres, ' ', pn.apellidos), pj.razon_social) AS cliente_nombre,
               f.total,
               cxc.saldo_pendiente AS saldo
        FROM cuentas_por_cobrar cxc
        JOIN facturas f ON cxc.factura_id = f.id
        LEFT JOIN personas_naturales pn ON f.cliente_id = pn.cliente_id
        LEFT JOIN personas_juridicas pj ON f.cliente_id = pj.cliente_id
        WHERE cxc.estado_id IN (1, 2)
    """)
    pendientes = cursor.fetchall()
    cursor.close()
    conn.close()
    return pendientes

# ─────────────────────────────────────────────
# PAGOS
# ─────────────────────────────────────────────

@app.post("/api/pagos")
def registrar_pago(pago: Pago):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        # Verificar saldo actual
        cursor.execute(
            "SELECT id, saldo_pendiente FROM cuentas_por_cobrar WHERE factura_id = %s AND estado_id IN (1,2)",
            (pago.factura_id,)
        )
        row = cursor.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="No existe cuenta por cobrar activa para esta factura.")
        cxc_id, saldo = row
        if pago.monto > float(saldo):
            raise HTTPException(status_code=400, detail="El monto supera el saldo pendiente.")

        cursor.execute(
            "INSERT INTO pagos_cliente (factura_id, monto, forma_pago_id, anulado) VALUES (%s, %s, %s, 0)",
            (pago.factura_id, pago.monto, pago.forma_pago_id)
        )
        nuevo_saldo = float(saldo) - pago.monto
        nuevo_estado = 3 if nuevo_saldo == 0 else 1  # 3=CANCELADA
        cursor.execute(
            "UPDATE cuentas_por_cobrar SET saldo_pendiente = %s, estado_id = %s WHERE id = %s",
            (round(nuevo_saldo, 2), nuevo_estado, cxc_id)
        )
        if nuevo_saldo == 0:
            cursor.execute("UPDATE facturas SET estado_id = 3 WHERE id = %s", (pago.factura_id,))

        conn.commit()
        return {"success": True, "saldo_restante": round(nuevo_saldo, 2)}
    except HTTPException:
        raise
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cursor.close()
        conn.close()

# ─────────────────────────────────────────────
# MÓDULO B — Productos con stock real
# ─────────────────────────────────────────────

@app.get("/api/productos")
def get_productos():
    """
    Consulta productos directamente desde modulo_b.productos.
    Schema real: estado ENUM('ACTIVO','INACTIVO'), columna precio_costo, stock_minimo.
    """
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("""
        SELECT product_id        AS id,
               descripcion       AS nombre,
               precio_venta,
               stock_actual      AS stock,
               stock_minimo,
               marca,
               talla,
               color
        FROM modulo_b.productos
        WHERE estado = 'ACTIVO'
        ORDER BY descripcion
    """)
    productos = cursor.fetchall()
    cursor.close()
    conn.close()
    return productos

# ─────────────────────────────────────────────
# MÓDULO D — Tarifas IVA reales
# ─────────────────────────────────────────────

@app.get("/api/tarifas-iva")
def get_tarifas_iva():
    """
    Devuelve las tarifas IVA vigentes desde modulo_d.tarifas_iva.
    Campos: id_tarifa, codigo, porcentaje, descripcion
    """
    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("""
        SELECT id_tarifa, codigo, porcentaje, descripcion
        FROM modulo_d.tarifas_iva
        WHERE activo = 1
          AND (fecha_vigencia_hasta IS NULL OR fecha_vigencia_hasta >= CURDATE())
        ORDER BY porcentaje
    """)
    tarifas = cursor.fetchall()
    cursor.close()
    conn.close()
    return tarifas

@app.get("/api/configuracion/iva")
def get_iva_default():
    """
    Devuelve la tarifa IVA estándar (la de mayor porcentaje activo),
    compatible con el comportamiento anterior del frontend.
    """
    conn = get_db_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT porcentaje FROM modulo_d.tarifas_iva
        WHERE activo = 1
          AND (fecha_vigencia_hasta IS NULL OR fecha_vigencia_hasta >= CURDATE())
        ORDER BY porcentaje DESC
        LIMIT 1
    """)
    row = cursor.fetchone()
    cursor.close()
    conn.close()
    return {"iva": float(row[0]) / 100 if row else 0.15}
