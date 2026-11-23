-- =====================================================================
-- 02_limpieza_staging.sql
-- Etapa 2: limpieza y tipado de los datos cargados.
--
-- Entrada : staging.vuelos_raw  (todo TEXT, tal como viene del CSV)
-- Salida  : staging.vuelos      (tipada y limpia)
--
-- Reglas de limpieza:
--   1. Se recortan espacios (btrim) en todas las columnas de texto.
--   2. Las cadenas vacias se convierten en NULL.
--   3. Se convierten tipos por nombre de columna:
--        fecha    -> date
--        enteros  -> integer   (BTS los trae como '1.00')
--        decimales-> numeric
--      Las horas hhmm (crsdeptime, deptime, etc.) se dejan como texto
--      para no perder el formato (p. ej. '0630' o '2400').
--   4. staging.vuelos_raw se conserva intacta como evidencia de la carga.
--
-- Nota: la logica es dinamica, asi que funciona con las columnas que haya
-- en staging.vuelos_raw. Las columnas que no esten en las listas de abajo
-- quedan como TEXT limpio.
-- =====================================================================

DROP TABLE IF EXISTS staging.vuelos;

DO $$
DECLARE
    cols_fecha text[] := ARRAY['flightdate'];

    cols_enteras text[] := ARRAY[
        'year', 'quarter', 'month', 'dayofmonth', 'dayofweek',
        'dot_id_reporting_airline', 'flight_number_reporting_airline',
        'originairportid', 'originairportseqid', 'origincitymarketid',
        'originstatefips', 'originwac',
        'destairportid', 'destairportseqid', 'destcitymarketid',
        'deststatefips', 'destwac',
        'depdel15', 'arrdel15', 'cancelled', 'diverted', 'flights',
        'distancegroup', 'departuredelaygroups', 'arrivaldelaygroups',
        'divairportlandings'
    ];

    cols_decimales text[] := ARRAY[
        'depdelay', 'depdelayminutes', 'taxiout', 'taxiin',
        'arrdelay', 'arrdelayminutes',
        'crselapsedtime', 'actualelapsedtime', 'airtime', 'distance',
        'carrierdelay', 'weatherdelay', 'nasdelay', 'securitydelay',
        'lateaircraftdelay', 'totaladdgtime', 'longestaddgtime',
        'divactualelapsedtime', 'divarrdelay', 'divdistance'
    ];

    lista text;
BEGIN
    SELECT string_agg(
        CASE
            WHEN cn = 'id_raw' OR cn = 'archivo_origen'
                THEN format('%I', cn)
            WHEN cn = ANY (cols_fecha)
                THEN format('NULLIF(btrim(%I), '''')::date AS %I', cn, cn)
            WHEN cn = ANY (cols_enteras)
                THEN format('NULLIF(btrim(%I), '''')::numeric::integer AS %I', cn, cn)
            WHEN cn = ANY (cols_decimales)
                THEN format('NULLIF(btrim(%I), '''')::numeric AS %I', cn, cn)
            ELSE format('NULLIF(btrim(%I), '''') AS %I', cn, cn)
        END,
        ', ' ORDER BY pos)
    INTO lista
    FROM (
        SELECT column_name::text AS cn, ordinal_position AS pos
        FROM information_schema.columns
        WHERE table_schema = 'staging' AND table_name = 'vuelos_raw'
    ) t;

    IF lista IS NULL THEN
        RAISE EXCEPTION 'No existe staging.vuelos_raw. Ejecuta primero 01_cargar_staging.py';
    END IF;

    EXECUTE 'CREATE TABLE staging.vuelos AS SELECT ' || lista || ' FROM staging.vuelos_raw';
END $$;

ALTER TABLE staging.vuelos ADD PRIMARY KEY (id_raw);

ANALYZE staging.vuelos;

-- Verificacion rapida: ambas tablas deben tener el mismo numero de filas
SELECT (SELECT count(*) FROM staging.vuelos_raw) AS filas_raw,
       (SELECT count(*) FROM staging.vuelos)     AS filas_limpias;
