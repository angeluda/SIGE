# Módulo A: Facturación y Cuentas por Cobrar | SIGE

Este módulo es un componente central del **Sistema Integrado de Gestión Empresarial (SIGE)**. Su objetivo principal es administrar el flujo comercial de la empresa, abarcando la gestión de clientes, la emisión de facturas y el control de cuentas por cobrar. Además, se integra de forma transversal con los módulos de Inventarios (Módulo B) e Impuestos (Módulo D) para validar existencias, consultar precios y aplicar normativas tributarias vigentes.

## Tecnologías Usadas

* **Frontend:** HTML5, CSS3 (Tailwind CSS vía CDN), JavaScript Vanilla, Lucide Icons.
* **Backend:** Python 3, FastAPI, Uvicorn (Servidor ASGI).
* **Base de Datos:** MySQL 8.0 (arquitectura modular por *schemas*, usando el conector `mysql-connector-python`).
* **Herramientas Adicionales:** Node.js / npm (para servir el frontend localmente y evitar bloqueos de CORS).

## Pasos Exactos de Instalación y Ejecución

Para ejecutar correctamente este módulo y visualizar el Prototipo MVP de manera local, siga estrictamente los siguientes pasos en orden:

### 1. Preparación de la Base de Datos (MySQL)

1.  Asegúrese de tener instalado y en ejecución un servidor **MySQL** (por ejemplo, a través de XAMPP, WAMP, Docker o instalación nativa).
2.  Abra su gestor de base de datos preferido (MySQL Workbench, DBeaver, phpMyAdmin, etc.).
3.  Navegue a la carpeta `ModuloA/DDL/` y ejecute el script `DDL_ModuloA.sql`. Esto creará el esquema, las tablas necesarias y sus relaciones.
4.  Navegue a la carpeta `ModuloA/DML/` y ejecute el script `DML_ModuloA.sql` para poblar la base de datos con los registros de prueba necesarios para la demostración.
    * *Nota de Integración: Asegúrese de que los esquemas de los otros módulos (`modulo_b`, `modulo_d`) también estén creados y tengan datos si desea probar la consulta de stock e IVA a profundidad.*

### 2. Instalación y Ejecución del Backend (FastAPI)

1.  Abra una terminal o línea de comandos.
2.  Navegue hasta la carpeta del backend del Módulo A:
    ```bash
    cd ModuloA/backend
    ```
3.  (Opcional pero recomendado) Cree y active un entorno virtual de Python.
4.  Instale las dependencias requeridas para el servidor ejecutando el siguiente comando:
    ```bash
    pip install fastapi uvicorn mysql-connector-python pydantic
    ```
5.  Inicie el servidor local de la API ejecutando:
    ```bash
    uvicorn main:app --reload
    ```
6.  La terminal indicará que el servidor se ha iniciado correctamente. El backend estará corriendo y escuchando peticiones en `http://localhost:8000`.
    * *Tip: Puede revisar la documentación interactiva de los endpoints creados accediendo a `http://localhost:8000/docs` desde su navegador.*

### 3. Ejecución del Frontend (Interfaz de Usuario)

Para que el navegador pueda realizar peticiones al backend sin ser bloqueado por las políticas de seguridad (CORS o la restricción de archivos locales `file://`), debe servir el frontend usando un servidor estático ligero.

1.  Asegúrese de tener **Node.js** instalado en su sistema.
2.  Abra una nueva terminal (manteniendo la terminal del backend abierta y corriendo).
3.  Navegue hasta la carpeta del frontend del Módulo A:
    ```bash
    cd ModuloA/frontend
    ```
4.  Instale el paquete `serve` de forma global (si no lo ha hecho antes):
    ```bash
    npm install -g serve
    ```
5.  Ejecute el servidor estático en esa carpeta:
    ```bash
    serve .
    ```
6.  La terminal le mostrará una dirección local (por lo general `http://localhost:3000`). Abra esa URL en su navegador web y seleccione el archivo `MVP_Modulo_A.html`.
