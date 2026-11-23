# Etapa 2: Limpieza y carga preliminar de datos


## Estructura del repositorio (etapa 2)

```
.
├── data/                       
├── scripts/
│   └── 01_cargar_staging.py
├── sql/
│   ├── 02_limpieza_staging.sql
│   └── 03_analisis_exploratorio.sql
├── requirements.txt
└── .gitignore
```

## Requisitos

- **Docker** (Docker Desktop en Windows) con un contenedor de PostgreSQL 16.
- **Python 3.10 o superior** y `pip`.
- **DBeaver** (opcional, para ejecutar los `.sql` y ver los resultados).
- Archivo CSV de BTS: *Reporting Carrier On-Time Performance (1987-present)*, descargado desde
  <https://www.transtats.bts.gov/DatabaseInfo.asp?QO_VQ=EFD> con **Download → Prezipped File**.
  El que usamos: año **2024**, mes **3** (`On_Time_Reporting_Carrier_On_Time_Performance_(1987_present)_2024_3.csv`).

Los comandos están escritos para **PowerShell (Windows)**.

## Parámetros de conexión

Usamos estos valores (base de datos local de desarrollo):

| Parámetro | Variable de entorno | Valor |
|---|---|---|
| Servidor | `PGHOST` | `localhost` |
| Puerto | `PGPORT` | `5435` |
| Base de datos | `PGDATABASE` | `vuelos_db` |
| Usuario | `PGUSER` | `admin_user` |
| Contraseña | `PGPASSWORD` | `admin_pass` |

> **Importante:** el script `01_cargar_staging.py` trae por defecto otros valores (`5432`, `mi_base`, `admin`, `mi_password`). Si tu base tiene los datos de la tabla anterior, **debes definir las variables de entorno** antes de ejecutarlo (paso 4). Estas contraseñas son solo para desarrollo local; no uses credenciales reales en el repositorio.

## Pasos para reproducir la carga

### 1. Levantar la base de datos

Abre **Docker Desktop** y comprueba que el contenedor de PostgreSQL esté activo:

```powershell
docker ps
```

Si no aparece en la lista, inícialo (sustituye por el nombre de tu contenedor):

```powershell
docker start <nombre_del_contenedor>
```

Si todavía no existe la base, se puede crear así (equivalente a los parámetros de la tabla anterior):

```powershell
docker run --name vuelos-postgres `
  -e POSTGRES_USER=admin_user -e POSTGRES_PASSWORD=admin_pass -e POSTGRES_DB=vuelos_db `
  -p 5435:5432 -v vuelos_pgdata:/var/lib/postgresql/data -d postgres:16
```


### 2. Entrar a la carpeta del proyecto

Todos los comandos siguientes se ejecutan **desde la carpeta raíz del proyecto** (la que contiene `scripts`, `sql` y `requirements.txt`):

```powershell
cd C:\ruta\al\proyecto-vuelos
dir
```

### 3. Crear el entorno de Python e instalar dependencias

Se recomienda un entorno virtual, para que `python` y `pip` apunten siempre al mismo intérprete:

```powershell
py -m venv .venv
.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
```

Si PowerShell bloquea la activación, ejecuta antes `Set-ExecutionPolicy -Scope Process Bypass`.

Si el comando `python` abre un Python que no es el que quieres (ver [Solución de problemas](#solución-de-problemas)), usa la ruta completa del Python que sí tiene `pip`, por ejemplo:

```powershell
$py = "C:\Users\<usuario>\AppData\Local\Microsoft\WindowsApps\PythonSoftwareFoundation.Python.3.11_qbz5n2kfra8p0\python.exe"
& $py -m pip install -r requirements.txt
```

### 4. Cargar el CSV a staging (todo como texto)

Descomprime el `.zip` de BTS y copia el CSV a la carpeta `data/`. Luego define la conexión y ejecuta el script:

```powershell
$env:PGHOST = "localhost"
$env:PGPORT = "5435"
$env:PGDATABASE = "vuelos_db"
$env:PGUSER = "admin_user"
$env:PGPASSWORD = "admin_pass"

python scripts\01_cargar_staging.py "data\On_Time_Reporting_Carrier_On_Time_Performance_(1987_present)_2024_3.csv"
```

(Con la ruta completa del Python, sustituye `python` por `& $py`.) Las variables de entorno solo valen para la ventana de PowerShell actual; si la cierras, hay que definirlas de nuevo.

Salida esperada para el archivo de marzo de 2024:

```
Cargado On_Time_Reporting_Carrier_On_Time_Performance_(1987_present)_2024_3.csv: 591767 filas
Columna vacia eliminada: _extra109
staging.vuelos_raw: 591767 filas, 109 columnas de datos
```

El script puede ejecutarse varias veces: elimina y vuelve a crear `staging.vuelos_raw` en cada corrida.

### 5. Limpiar y tipar

Desde **DBeaver**: conéctate a `vuelos_db` (puerto 5435), refresca la conexión con **F5** (debe aparecer el esquema `staging`), abre `sql/02_limpieza_staging.sql` y usa **Ejecutar script** (Alt+X).

Alternativa desde la terminal (sustituye por el nombre de tu contenedor):

```powershell
Get-Content sql\02_limpieza_staging.sql -Raw | docker exec -i <nombre_del_contenedor> psql -U admin_user -d vuelos_db
```

Al terminar, debe mostrar el mismo número de filas en ambas tablas:

| filas_raw | filas_limpias |
|---|---|
| 591767 | 591767 |

### 6. Análisis exploratorio

En DBeaver, abre y ejecuta `sql/03_analisis_exploratorio.sql` con Alt+X. Cada consulta devuelve una pestaña de resultados. Para comprobar que la carga está bien:

```sql
SELECT count(*) FROM staging.vuelos_raw;   -- 591767
SELECT count(*) FROM staging.vuelos;       -- 591767
```

> **Nota:** si importaron el CSV antes con el asistente de DBeaver, puede existir una tabla en el esquema `public` con el nombre del archivo. No forma parte del proceso: el flujo reproducible usa solo `staging`.

## Solución de problemas

| Síntoma | Causa y solución |
|---|---|
| `ERROR: Could not open requirements file ... 'requirements.txt'` | No estás en la carpeta del proyecto. Haz `cd` a la carpeta que contiene `requirements.txt` (paso 2). |
| `ModuleNotFoundError: No module named 'psycopg2'` aunque `pip` dice *Requirement already satisfied* | `pip` y `python` apuntan a intérpretes distintos. Usa el entorno virtual (paso 3) o instala con `python -m pip install -r requirements.txt`, que usa el mismo Python que ejecuta el script. |
| `C:\msys64\ucrt64\bin\python.exe: No module named pip` | `python` abre el Python de MSYS2, que no trae `pip`. Usa `py` (o el entorno virtual) o la ruta completa del Python de Windows. Puedes ver cuál usas con `where.exe python`. |
| `UnicodeDecodeError: 'utf-8' codec can't decode byte 0xf3 ... ` al conectar | Es un **error de conexión** cuyo mensaje, en español, trae acentos que Python no puede leer. Las causas habituales son un contenedor apagado o datos de conexión incorrectos (puerto, base, usuario o contraseña). Revisa `docker ps` y las variables de entorno. Para ver el mensaje real, ejecuta el diagnóstico de abajo. Cambiar `PGCLIENTENCODING` **no** lo resuelve. |
| DBeaver no muestra el esquema `staging` | Falta refrescar: selecciona la conexión (o *Esquemas*) y pulsa **F5**. |

**Diagnóstico de conexión** (muestra el mensaje real del error):

```powershell
@'
import psycopg2
try:
    psycopg2.connect(host="localhost", port=5435, dbname="vuelos_db", user="admin_user", password="admin_pass")
    print("Conexion OK")
except UnicodeDecodeError as e:
    print(e.object.decode("cp1252"))
'@ | python -
```

Si imprime `Conexion OK`, la base responde con esos datos y el problema está en las variables de entorno del paso 4.

## Descripción de los scripts

| Script | Qué hace |
|---|---|
| `scripts/01_cargar_staging.py` | Lee el encabezado del CSV, crea el esquema `staging` y la tabla `staging.vuelos_raw` con **todas las columnas como TEXT**, y carga el archivo con `COPY`. Agrega `id_raw` y `archivo_origen`, y elimina la columna vacía que resulta de la coma final de cada línea. La conexión se configura con las variables `PGHOST`, `PGPORT`, `PGDATABASE`, `PGUSER` y `PGPASSWORD`. |
| `sql/02_limpieza_staging.sql` | Crea `staging.vuelos` a partir de `vuelos_raw`: recorta espacios, convierte cadenas vacías en `NULL` y asigna tipos (`date`, `integer`, `numeric`). Las horas `hhmm` quedan como texto. Conserva `vuelos_raw` intacta. |
| `sql/03_analisis_exploratorio.sql` | Crea la función `staging.perfil_columnas()` y la tabla `staging.perfil_vuelos`, y ejecuta las consultas del análisis exploratorio (ver abajo). |

### Decisiones de limpieza

- Carga en dos pasos (texto → tipado) para no perder filas por errores de conversión y para conservar evidencia del dato original.
- **[COMPLETAR]** Qué hicieron con duplicados, nulos e inconsistencias después del análisis (por ejemplo, si eliminaron filas repetidas y por qué).

## Resultados del análisis exploratorio

### Dimensiones
| Filas | Columnas |
|---|---|
| 591,767 | 109 (más `id_raw` y `archivo_origen` añadidas al cargar) |

### Atributos con valores únicos
| Columna | Tipo | Total | Distintos |
|---|---|---|---|
| div2tailnum | text | 591,797 | 10 |
| div2wheelsoff | text | 591,797 | 10 |
| div2wheelson | text | 591,797 | 26 |
| id_raw | bigint | 591,797 | 591,797 |


### Rango de fechas
| Fecha mínima | Fecha máxima | Días cubiertos | Días con vuelos |
|---|---|---|---|
| 2024-03-01 | 2024-03-31 | 31 | 31 |

### Estadísticas numéricas
| Atributo | Valores no nulos | Mínimo | Máximo | Promedio |
|---|---|---|---|---|
| actualelapsedtime | 585413 | 17.00 |  712.00 | 143.07 |
| airtime | 585413 | 8.00 | 674.00 | 117.46 |
| arrdelay | 585413 | -95.00 | 3359.00 | 6.5 |
| arrdelayminutes | 585413 | 0.00 | 3359.00 | 15.56 |
| carrierdelay | 122032 | 0.00 | 3359.00 | 22.42 |
| crselapsedtime | 591767 | -160.00 | 710.00 | 149.01 | 
| depdelay | 586822 | -59.00 | 3360.00 | 12.45 |
| depdelayminutes | 586822 | 0.00| 3360.00 | 15.70 |
| distance | 591767 | 31.00 | 5095.00 | 843.13 |
| lateaircraftdelay | 122032 | 0.00 | 2506.00 | 29.36 |
| nasdelay | 122032 | 0.00 | 1501.00 | 14.94 |
| securitydelay | 122032 | 0.00 | 430.00 | 0.15 |
| taxiin | 586505 | 1.00 | 187.00 | 7.95 |
| taxiout | 586684 | 1.00 | 171.00 | 17.67 |
| weatherdelay | 122032 | 0.00 | 1479.00 | 2.93 |


### Duplicados categóricos
**[COMPLETAR]** (filas repetidas, vuelos repetidos por clave natural, códigos con más de un nombre).

### Columnas redundantes
**[COMPLETAR]** (columnas constantes y pares equivalentes, p. ej. `origin` / `originairportid`; columnas derivables de `flightdate`). Indicar cuáles se eliminarán o se tratarán en la normalización.

### Distribución categórica
**[COMPLETAR]** (vuelos por aerolínea, por aeropuerto de origen, por mes, cancelados, etc.).

### Valores nulos
**[COMPLETAR]** (columnas con más nulos). Los nulos en horas reales y causas de retraso son esperados en vuelos cancelados o puntuales.

### Inconsistencias
| Regla | Casos |
|---|---|
| **[COMPLETAR]** | |
