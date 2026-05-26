from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
from datetime import date
import mysql.connector

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

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

class DatabaseConnection:
    _instancia = None

    def __new__(cls):
        if cls._instancia is None:
            cls._instancia = super(DatabaseConnection, cls).__new__(cls)
        return cls._instancia

    def get_connection(self):
        return mysql.connector.connect(
            host="localhost",
            user="root",
            password="password",
            database="modulo_a"
        )

db_singleton = DatabaseConnection()

def get_db_connection():
    return db_singleton.get_connection()

class ObservadorFactura:
    def update(self, numero_factura):
        print("Alerta: Se registro la factura " + numero_factura)

class GestorAlertas:
    def __init__(self):
        self.observadores = []

    def agregar_observador(self, observador):
        self.observadores.append(observador)

    def notificar(self, numero_factura):
        for obs in self.observadores:
            obs.update(numero_factura)

gestor_alertas = GestorAlertas()
notificador = ObservadorFactura()
gestor_alertas.agregar_observador(notificador)

class FacturaFactory:
    def procesar_total(self, detalles, cursor):
        total = 0.0
        for d in detalles:
            subtotal = (d.precio_unitario * d.cantidad) - d.descuento
            cursor.execute(
                "SELECT porcentaje FROM modulo_d.tarifas_iva WHERE id_tarifa = %s AND activo = 1",
                (d.id_tarifa,)
            )
            row = cursor.fetchone()
            porcentaje = float(row[0]) / 100 if row else 0.15
            total += subtotal * (1 + porcentaje)
        return round(total, 2)

factura_factory = FacturaFactory()

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
        total = factura_factory.procesar_total(factura.detalles, cursor)

        cursor.execute(
            """INSERT INTO facturas (numero_factura, fecha_emision, total, cliente_id, vendedor_id, estado_id)
               VALUES (%s, %s, %s, %s, %s, 1)""",
            (factura.numero_factura, date.today(), total, factura.cliente_id, factura.vendedor_id)
        )
        factura_id = cursor.lastrowid

        for d in factura.detalles:
            cursor.execute(
                """INSERT INTO detalle_factura (factura_id, product_id, id_tarifa, cantidad, precio_unitario, descuento)
                   VALUES (%s, %s, %s, %s, %s, %s)""",
                (factura_id, d.product_id, d.id_tarifa, d.cantidad, d.precio_unitario, d.descuento)
            )
            cursor.callproc("modulo_b.sp_registrar_salida_inventario",
                            [d.product_id, 1, d.cantidad, factura.numero_factura])

        cursor.execute("SELECT dias_credito FROM clientes WHERE id = %s", (factura.cliente_id,))
        row = cursor.fetchone()
        dias = row[0] if row else 0
        if dias and dias > 0:
            cursor.execute(
                """INSERT INTO cuentas_por_cobrar (factura_id, fecha_vencimiento, saldo_pendiente, estado_id)
                   VALUES (%s, DATE_ADD(CURDATE(), INTERVAL %s DAY), %s, 1)""",
                (factura_id, dias, total)
            )

        conn.commit()
        gestor_alertas.notificar(factura.numero_factura)
        return {"success": True, "id": factura_id, "total": total}
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

@app.post("/api/pagos")
def registrar_pago(pago: Pago):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "SELECT id, saldo_pendiente FROM cuentas_por_cobrar WHERE factura_id = %s AND estado_id IN (1,2)",
            (pago.factura_id,)
        )
        row = cursor.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="No existe cuenta.")
        cxc_id, saldo = row
        nuevo_saldo = saldo - pago.monto
        if nuevo_saldo < 0:
            raise HTTPException(status_code=400, detail="Monto excede el saldo.")
        estado_id = 3 if nuevo_saldo == 0 else 1
        cursor.execute(
            "UPDATE cuentas_por_cobrar SET saldo_pendiente = %s, estado_id = %s WHERE id = %s",
            (nuevo_saldo, estado_id, cxc_id)
        )
        cursor.execute(
            "INSERT INTO pagos_cliente (factura_id, monto, forma_pago_id) VALUES (%s, %s, %s)",
            (pago.factura_id, pago.monto, pago.forma_pago_id)
        )
        conn.commit()
        return {"success": True, "saldo_restante": nuevo_saldo}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cursor.close()
        conn.close()
