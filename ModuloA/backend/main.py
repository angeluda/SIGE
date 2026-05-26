from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
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

class LineaFactura(BaseModel):
    product_id: int
    id_tarifa: int
    cantidad: int
    precio_unitario: float
    descuento: float = 0.0

class DatosFacturaDTO(BaseModel):
    numero_factura: str
    cliente_id: int
    vendedor_id: int
    detalles: List[LineaFactura]

class DatosNotaCreditoDTO(BaseModel):
    numero_nota: str
    factura_id: int
    motivo: str
    detalles: List[LineaFactura]

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

    @classmethod
    def getInstancia(cls):
        if cls._instancia is None:
            cls()
        return cls._instancia

    def connect(self):
        return mysql.connector.connect(
            host="localhost",
            user="root",
            password="",
            database="sige"
        )

class ComprobanteFactory:
    def crear_comprobante(self, dto, cursor):
        pass

class FacturaFactory(ComprobanteFactory):
    def crear_comprobante(self, dto, cursor):
        total = 0.0
        for d in dto.detalles:
            subtotal = (d.precio_unitario * d.cantidad) - d.descuento
            cursor.execute("SELECT porcentaje FROM modulo_d.tarifas_iva WHERE id_tarifa = %s", (d.id_tarifa,))
            row = cursor.fetchone()
            porc = float(row[0])/100 if row else 0.15
            total += subtotal * (1 + porc)
        
        cursor.execute(
            "INSERT INTO facturas (numero_factura, fecha_emision, total, cliente_id, vendedor_id, estado_id) VALUES (%s, %s, %s, %s, %s, 1)",
            (dto.numero_factura, date.today(), total, dto.cliente_id, dto.vendedor_id)
        )
        return cursor.lastrowid, total

class NotaCreditoFactory(ComprobanteFactory):
    def crear_comprobante(self, dto, cursor):
        cursor.execute(
            "INSERT INTO notas_credito (numero_nota, factura_id, fecha_emision, motivo) VALUES (%s, %s, %s, %s)",
            (dto.numero_nota, dto.factura_id, date.today(), dto.motivo)
        )
        return cursor.lastrowid, 0.0

class Observador:
    def update(self, cuenta_id, factura_id, dias_vencidos):
        pass

class NotificadorVencimiento(Observador):
    def update(self, cuenta_id, factura_id, dias_vencidos):
        print("ALERTA: La cuenta " + str(cuenta_id) + " de la factura " + str(factura_id) + " esta vencida por " + str(dias_vencidos) + " dias.")

class VerificadorVencimientos:
    def __init__(self):
        self._observadores = []

    def attach(self, observer):
        self._observadores.append(observer)

    def verificar(self):
        db = DatabaseConnection.getInstancia()
        conn = db.connect()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT id, factura_id, DATEDIFF(CURDATE(), fecha_vencimiento) as dias FROM cuentas_por_cobrar WHERE estado_id = 1 AND fecha_vencimiento < CURDATE()")
        vencidas = cursor.fetchall()
        for v in vencidas:
            for obs in self._observadores:
                obs.update(v['id'], v['factura_id'], v['dias'])
            cursor.execute("UPDATE cuentas_por_cobrar SET estado_id = 2 WHERE id = %s", (v['id'],))
        conn.commit()
        cursor.close()
        conn.close()

verificador = VerificadorVencimientos()
verificador.attach(NotificadorVencimiento())

@app.get("/api/productos")
def get_productos():
    db = DatabaseConnection.getInstancia()
    conn = db.connect()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT product_id AS id, descripcion AS nombre, precio_venta, stock_actual AS stock, stock_minimo, marca, talla, color FROM modulo_b.productos WHERE estado = 'ACTIVO' ORDER BY descripcion")
    productos = cursor.fetchall()
    cursor.close()
    conn.close()
    return productos

@app.get("/api/tarifas-iva")
def get_tarifas_iva():
    db = DatabaseConnection.getInstancia()
    conn = db.connect()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT id_tarifa, codigo, porcentaje, descripcion FROM modulo_d.tarifas_iva WHERE activo = 1 AND (fecha_vigencia_hasta IS NULL OR fecha_vigencia_hasta >= CURDATE()) ORDER BY porcentaje")
    tarifas = cursor.fetchall()
    cursor.close()
    conn.close()
    return tarifas

@app.get("/api/configuracion/iva")
def get_iva_default():
    db = DatabaseConnection.getInstancia()
    conn = db.connect()
    cursor = conn.cursor()
    cursor.execute("SELECT porcentaje FROM modulo_d.tarifas_iva WHERE activo = 1 AND (fecha_vigencia_hasta IS NULL OR fecha_vigencia_hasta >= CURDATE()) ORDER BY porcentaje DESC LIMIT 1")
    row = cursor.fetchone()
    cursor.close()
    conn.close()
    return {"iva": float(row[0]) / 100 if row else 0.15}

@app.get("/api/vendedores")
def get_vendedores():
    db = DatabaseConnection.getInstancia()
    conn = db.connect()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT id, CONCAT(nombres, ' ', apellidos) as nombre FROM vendedores WHERE estado = 'ACTIVO'")
    vendedores = cursor.fetchall()
    cursor.close()
    conn.close()
    return vendedores

@app.get("/api/formas-pago")
def get_formas_pago():
    db = DatabaseConnection.getInstancia()
    conn = db.connect()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT id, nombre FROM cat_formas_pago ORDER BY id")
    formas = cursor.fetchall()
    cursor.close()
    conn.close()
    return formas

@app.get("/api/clientes")
def get_clientes():
    db = DatabaseConnection.getInstancia()
    conn = db.connect()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT c.id, c.tipo_cliente_id, COALESCE(pn.cedula, pj.ruc) AS identificacion, COALESCE(CONCAT(pn.nombres, ' ', pn.apellidos), pj.razon_social) AS nombre, c.correo_electronico AS email, c.direccion FROM clientes c LEFT JOIN personas_naturales pn ON c.id = pn.cliente_id LEFT JOIN personas_juridicas pj ON c.id = pj.cliente_id WHERE c.estado = 'ACTIVO'")
    clientes = cursor.fetchall()
    cursor.close()
    conn.close()
    return clientes

@app.post("/api/clientes")
def create_cliente(cliente: Cliente):
    db = DatabaseConnection.getInstancia()
    conn = db.connect()
    cursor = conn.cursor()
    try:
        cursor.execute("INSERT INTO clientes (tipo_cliente_id, direccion, correo_electronico, dias_credito) VALUES (%s, %s, %s, 0)", (cliente.tipo_cliente_id, cliente.direccion, cliente.email))
        cliente_id = cursor.lastrowid
        if cliente.tipo_cliente_id == 1:
            partes = cliente.nombre.strip().split(' ', 1)
            nombres = partes[0]
            apellidos = partes[1] if len(partes) > 1 else ''
            cursor.execute("INSERT INTO personas_naturales (cliente_id, cedula, nombres, apellidos) VALUES (%s, %s, %s, %s)", (cliente_id, cliente.identificacion, nombres, apellidos))
        else:
            cursor.execute("INSERT INTO personas_juridicas (cliente_id, ruc, razon_social) VALUES (%s, %s, %s)", (cliente_id, cliente.identificacion, cliente.nombre))
        conn.commit()
        return {"success": True, "id": cliente_id}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cursor.close()
        conn.close()

@app.put("/api/clientes/{cliente_id}")
def update_cliente(cliente_id: int, cliente: Cliente):
    db = DatabaseConnection.getInstancia()
    conn = db.connect()
    cursor = conn.cursor()
    try:
        cursor.execute("UPDATE clientes SET direccion = %s, correo_electronico = %s, tipo_cliente_id = %s WHERE id = %s", (cliente.direccion, cliente.email, cliente.tipo_cliente_id, cliente_id))
        
        if cliente.tipo_cliente_id == 1:
            partes = cliente.nombre.strip().split(' ', 1)
            nombres = partes[0]
            apellidos = partes[1] if len(partes) > 1 else ''
            cursor.execute("UPDATE personas_naturales SET cedula = %s, nombres = %s, apellidos = %s WHERE cliente_id = %s", (cliente.identificacion, nombres, apellidos, cliente_id))
        else:
            cursor.execute("UPDATE personas_juridicas SET ruc = %s, razon_social = %s WHERE cliente_id = %s", (cliente.identificacion, cliente.nombre, cliente_id))
            
        conn.commit()
        return {"success": True}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cursor.close()
        conn.close()

@app.delete("/api/clientes/{cliente_id}")
def delete_cliente(cliente_id: int):
    db = DatabaseConnection.getInstancia()
    conn = db.connect()
    cursor = conn.cursor()
    try:
        cursor.execute("UPDATE clientes SET estado = 'INACTIVO' WHERE id = %s", (cliente_id,))
        conn.commit()
        return {"success": True}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cursor.close()
        conn.close()

@app.get("/api/facturas")
def get_facturas():
    db = DatabaseConnection.getInstancia()
    conn = db.connect()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT f.id, f.numero_factura, DATE_FORMAT(f.fecha_emision, '%Y-%m-%d') AS fecha, f.total, f.cliente_id, ef.nombre AS estado, COALESCE(CONCAT(pn.nombres, ' ', pn.apellidos), pj.razon_social) AS cliente_nombre FROM facturas f JOIN cat_estados_facturas ef ON f.estado_id = ef.id LEFT JOIN personas_naturales pn ON f.cliente_id = pn.cliente_id LEFT JOIN personas_juridicas pj ON f.cliente_id = pj.cliente_id ORDER BY f.id DESC")
    facturas = cursor.fetchall()
    cursor.close()
    conn.close()
    return facturas

@app.post("/api/facturas")
def emitir_factura(dto: DatosFacturaDTO):
    db = DatabaseConnection.getInstancia()
    conn = db.connect()
    cursor = conn.cursor()
    try:
        factory = FacturaFactory()
        factura_id, total = factory.crear_comprobante(dto, cursor)
        
        for d in dto.detalles:
            cursor.execute("INSERT INTO detalle_factura (factura_id, product_id, id_tarifa, cantidad, precio_unitario, descuento) VALUES (%s, %s, %s, %s, %s, %s)", (factura_id, d.product_id, d.id_tarifa, d.cantidad, d.precio_unitario, d.descuento))
            cursor.callproc("modulo_b.sp_registrar_salida_inventario", [d.product_id, 1, d.cantidad, dto.numero_factura])

        cursor.execute("SELECT dias_credito FROM clientes WHERE id = %s", (dto.cliente_id,))
        row = cursor.fetchone()
        dias = row[0] if row else 0
        if dias > 0:
            cursor.execute("INSERT INTO cuentas_por_cobrar (factura_id, fecha_vencimiento, saldo_pendiente, estado_id) VALUES (%s, DATE_ADD(CURDATE(), INTERVAL %s DAY), %s, 1)", (factura_id, dias, total))
        
        conn.commit()
        return {"success": True, "factura_id": factura_id}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cursor.close()
        conn.close()

@app.post("/api/notas_credito")
def emitir_nota_credito(dto: DatosNotaCreditoDTO):
    db = DatabaseConnection.getInstancia()
    conn = db.connect()
    cursor = conn.cursor()
    try:
        factory = NotaCreditoFactory()
        nota_id, _ = factory.crear_comprobante(dto, cursor)
        conn.commit()
        return {"success": True, "nota_id": nota_id}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cursor.close()
        conn.close()

@app.get("/api/facturas/pendientes")
def get_facturas_pendientes():
    db = DatabaseConnection.getInstancia()
    conn = db.connect()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT f.id, f.numero_factura, COALESCE(CONCAT(pn.nombres, ' ', pn.apellidos), pj.razon_social) AS cliente_nombre, f.total, cxc.saldo_pendiente AS saldo FROM cuentas_por_cobrar cxc JOIN facturas f ON cxc.factura_id = f.id LEFT JOIN personas_naturales pn ON f.cliente_id = pn.cliente_id LEFT JOIN personas_juridicas pj ON f.cliente_id = pj.cliente_id WHERE cxc.estado_id IN (1, 2)")
    pendientes = cursor.fetchall()
    cursor.close()
    conn.close()
    return pendientes

@app.post("/api/pagos")
def registrar_pago(pago: Pago):
    db = DatabaseConnection.getInstancia()
    conn = db.connect()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT id, factura_id, saldo_pendiente FROM cuentas_por_cobrar WHERE factura_id = %s AND estado_id IN (1,2)", (pago.factura_id,))
        row = cursor.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="No existe cuenta activa")
        
        cxc_id, factura_id, saldo = row
        nuevo_saldo = float(saldo) - pago.monto
        
        if nuevo_saldo < 0:
            raise HTTPException(status_code=400, detail="Monto excede saldo")
            
        estado_id = 3 if nuevo_saldo <= 0 else 1 
        
        cursor.execute("UPDATE cuentas_por_cobrar SET saldo_pendiente = %s, estado_id = %s WHERE id = %s", (nuevo_saldo, estado_id, cxc_id))
        
        if nuevo_saldo <= 0:
            cursor.execute("UPDATE facturas SET estado_id = 3 WHERE id = %s", (factura_id,))
        
        cursor.execute("INSERT INTO pagos_cliente (factura_id, monto, forma_pago_id) VALUES (%s, %s, %s)", (pago.factura_id, pago.monto, pago.forma_pago_id))
        
        conn.commit()
        return {"success": True, "saldo_restante": nuevo_saldo}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cursor.close()
        conn.close()

@app.get("/api/vencimientos/ejecutar")
def ejecutar_verificacion_vencimientos():
    verificador.verificar()
    return {"message": "ok"}
