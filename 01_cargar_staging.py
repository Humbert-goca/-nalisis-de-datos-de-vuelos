#!/usr/bin/env python3
"""
Etapa 2 - Carga preliminar a staging.

Carga uno o varios CSV de BTS "Reporting Carrier On-Time Performance"
a PostgreSQL, SIN transformar nada:

- Crea el esquema `staging` y la tabla `staging.vuelos_raw`.
- TODAS las columnas se cargan como TEXT (carga "tal cual").
- Los nombres de columna salen del encabezado del CSV, en minusculas.
- Agrega `id_raw` (consecutivo) y `archivo_origen` (trazabilidad).
- Elimina la columna vacia final (los CSV de BTS terminan cada linea con una coma).

Uso:
    python scripts/01_cargar_staging.py data/archivo1.csv [data/archivo2.csv ...]

Conexion (variables de entorno opcionales; por defecto, el contenedor mi-postgres):
    PGHOST=localhost PGPORT=5432 PGDATABASE=mi_base PGUSER=admin PGPASSWORD=mi_password
"""
import csv
import os
import re
import sys
from pathlib import Path

import psycopg2
from psycopg2 import sql

CONEXION = {
    "host": os.getenv("PGHOST", "localhost"),
    "port": int(os.getenv("PGPORT", "5432")),
    "dbname": os.getenv("PGDATABASE", "mi_base"),
    "user": os.getenv("PGUSER", "admin"),
    "password": os.getenv("PGPASSWORD", "mi_password"),
}


def normalizar_columnas(encabezado):
    """Minusculas, solo letras/numeros/guion bajo; vacios -> _extraN; sin repetidos."""
    vistos = {}
    columnas = []
    for i, nombre in enumerate(encabezado):
        n = re.sub(r"\W+", "_", nombre.strip().strip('"').lower()).strip("_")
        if not n:
            n = f"_extra{i}"
        if n in vistos:
            vistos[n] += 1
            n = f"{n}_{vistos[n]}"
        else:
            vistos[n] = 0
        columnas.append(n)
    return columnas


def leer_encabezado(ruta):
    with open(ruta, encoding="utf-8-sig", newline="") as f:
        return normalizar_columnas(next(csv.reader(f)))


def main(rutas):
    rutas = [Path(r) for r in rutas]
    for r in rutas:
        if not r.is_file():
            sys.exit(f"No existe el archivo: {r}")

    columnas = leer_encabezado(rutas[0])
    for r in rutas[1:]:
        if leer_encabezado(r) != columnas:
            sys.exit(f"El encabezado de {r} no coincide con el de {rutas[0]}")

    conn = psycopg2.connect(**CONEXION)
    try:
        with conn, conn.cursor() as cur:
            cur.execute("CREATE SCHEMA IF NOT EXISTS staging")
            cur.execute("DROP TABLE IF EXISTS staging.vuelos_raw")

            definicion = sql.SQL(", ").join(
                sql.SQL("{} TEXT").format(sql.Identifier(c)) for c in columnas
            )
            cur.execute(
                sql.SQL(
                    "CREATE TABLE staging.vuelos_raw "
                    "(id_raw BIGSERIAL PRIMARY KEY, archivo_origen TEXT, {})"
                ).format(definicion)
            )

            copiar = sql.SQL(
                "COPY staging.vuelos_raw ({}) FROM STDIN WITH (FORMAT csv, HEADER true)"
            ).format(sql.SQL(", ").join(sql.Identifier(c) for c in columnas))

            for ruta in rutas:
                with open(ruta, encoding="utf-8-sig", newline="") as f:
                    cur.copy_expert(copiar.as_string(conn), f)
                cur.execute(
                    "UPDATE staging.vuelos_raw SET archivo_origen = %s "
                    "WHERE archivo_origen IS NULL",
                    (ruta.name,),
                )
                print(f"Cargado {ruta.name}: {cur.rowcount} filas")

            # Quitar la(s) columna(s) vacia(s) del final (coma sobrante de BTS)
            for c in [c for c in columnas if c.startswith("_extra")]:
                cur.execute(
                    sql.SQL(
                        "SELECT count(*) FROM staging.vuelos_raw "
                        "WHERE {col} IS NOT NULL AND btrim({col}) <> ''"
                    ).format(col=sql.Identifier(c))
                )
                if cur.fetchone()[0] == 0:
                    cur.execute(
                        sql.SQL("ALTER TABLE staging.vuelos_raw DROP COLUMN {}").format(
                            sql.Identifier(c)
                        )
                    )
                    print(f"Columna vacia eliminada: {c}")

            cur.execute("SELECT count(*) FROM staging.vuelos_raw")
            filas = cur.fetchone()[0]
            cur.execute(
                "SELECT count(*) FROM information_schema.columns "
                "WHERE table_schema = 'staging' AND table_name = 'vuelos_raw' "
                "AND column_name NOT IN ('id_raw', 'archivo_origen')"
            )
            cols = cur.fetchone()[0]
            print(f"staging.vuelos_raw: {filas} filas, {cols} columnas de datos")
    finally:
        conn.close()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1:])
