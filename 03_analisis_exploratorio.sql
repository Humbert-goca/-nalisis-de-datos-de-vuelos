-- =====================================================================
-- 03_analisis_exploratorio.sql
-- Etapa 2: analisis exploratorio con SQL sobre staging.vuelos.
-- Cada seccion corresponde a un punto de la rubrica.
-- En DBeaver: "Ejecutar script" (Alt+X) corre todo; Ctrl+Enter corre una consulta.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. Preparacion: funcion que perfila cada columna de una tabla
--    (total, nulos, distintos, si todos sus valores son unicos, si es constante)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION staging.perfil_columnas(p_tabla text DEFAULT 'vuelos')
RETURNS TABLE (
    columna      text,
    tipo         text,
    total        bigint,
    nulos        bigint,
    pct_nulos    numeric,
    distintos    bigint,
    es_unico     boolean,
    es_constante boolean
)
LANGUAGE plpgsql AS $$
DECLARE
    r record;
BEGIN
    FOR r IN
        SELECT c.column_name::text AS cn, c.data_type::text AS dt
        FROM information_schema.columns c
        WHERE c.table_schema = 'staging' AND c.table_name = p_tabla
        ORDER BY c.ordinal_position
    LOOP
        RETURN QUERY EXECUTE format(
            'SELECT %1$L::text, %2$L::text, count(*)::bigint,
                    (count(*) FILTER (WHERE %1$I IS NULL))::bigint,
                    round(100.0 * count(*) FILTER (WHERE %1$I IS NULL) / NULLIF(count(*), 0), 2),
                    count(DISTINCT %1$I)::bigint,
                    (count(DISTINCT %1$I) = count(%1$I) AND count(%1$I) > 0),
                    (count(DISTINCT %1$I) <= 1)
             FROM staging.%3$I',
            r.cn, r.dt, p_tabla);
    END LOOP;
END $$;

-- El perfil se guarda en una tabla para consultarlo varias veces
-- (y para documentarlo en el README)
DROP TABLE IF EXISTS staging.perfil_vuelos;
CREATE TABLE staging.perfil_vuelos AS
SELECT * FROM staging.perfil_columnas('vuelos');

-- ---------------------------------------------------------------------
-- 1. Dimensiones del conjunto de datos
-- ---------------------------------------------------------------------
SELECT count(*) AS filas FROM staging.vuelos;

SELECT count(*) AS columnas_de_datos
FROM information_schema.columns
WHERE table_schema = 'staging' AND table_name = 'vuelos'
  AND column_name NOT IN ('id_raw', 'archivo_origen');

-- ---------------------------------------------------------------------
-- 2. Atributos con valores unicos
--    (todas sus filas no nulas son distintas entre si; id_raw sale siempre)
-- ---------------------------------------------------------------------
SELECT columna, tipo, total, distintos
FROM staging.perfil_vuelos
WHERE es_unico
ORDER BY columna;

-- ---------------------------------------------------------------------
-- 3. Rango de fechas
-- ---------------------------------------------------------------------
SELECT min(flightdate)                          AS fecha_minima,
       max(flightdate)                          AS fecha_maxima,
       max(flightdate) - min(flightdate) + 1    AS dias_cubiertos,
       count(DISTINCT flightdate)               AS dias_con_vuelos
FROM staging.vuelos;

-- ---------------------------------------------------------------------
-- 4. Estadisticas numericas: minimo, maximo y promedio
--    (si una columna no existe en tu archivo, quita su linea)
-- ---------------------------------------------------------------------
SELECT m.atributo,
       count(m.valor)        AS valores_no_nulos,
       min(m.valor)          AS minimo,
       max(m.valor)          AS maximo,
       round(avg(m.valor), 2) AS promedio
FROM staging.vuelos v
CROSS JOIN LATERAL (VALUES
    ('depdelay',          v.depdelay),
    ('depdelayminutes',   v.depdelayminutes),
    ('arrdelay',          v.arrdelay),
    ('arrdelayminutes',   v.arrdelayminutes),
    ('taxiout',           v.taxiout),
    ('taxiin',            v.taxiin),
    ('crselapsedtime',    v.crselapsedtime),
    ('actualelapsedtime', v.actualelapsedtime),
    ('airtime',           v.airtime),
    ('distance',          v.distance),
    ('carrierdelay',      v.carrierdelay),
    ('weatherdelay',      v.weatherdelay),
    ('nasdelay',          v.nasdelay),
    ('securitydelay',     v.securitydelay),
    ('lateaircraftdelay', v.lateaircraftdelay)
) AS m(atributo, valor)
GROUP BY m.atributo
ORDER BY m.atributo;

-- ---------------------------------------------------------------------
-- 5. Duplicados
-- ---------------------------------------------------------------------
-- 5a. Filas completamente duplicadas (ignorando id_raw y archivo_origen)
SELECT count(*) AS filas,
       count(DISTINCT (to_jsonb(v) - 'id_raw' - 'archivo_origen')) AS filas_distintas,
       count(*) - count(DISTINCT (to_jsonb(v) - 'id_raw' - 'archivo_origen')) AS filas_repetidas
FROM staging.vuelos v;

-- 5b. Vuelos repetidos segun su clave natural
SELECT flightdate, reporting_airline, flight_number_reporting_airline,
       origin, dest, crsdeptime, count(*) AS veces
FROM staging.vuelos
GROUP BY flightdate, reporting_airline, flight_number_reporting_airline,
         origin, dest, crsdeptime
HAVING count(*) > 1
ORDER BY veces DESC
LIMIT 50;

-- 5c. Duplicados categoricos: un mismo codigo con mas de un nombre
SELECT origin AS codigo_aeropuerto,
       count(DISTINCT origincityname) AS variantes,
       array_agg(DISTINCT origincityname) AS nombres
FROM staging.vuelos
GROUP BY origin
HAVING count(DISTINCT origincityname) > 1
ORDER BY variantes DESC;

SELECT reporting_airline AS codigo_aerolinea,
       count(DISTINCT dot_id_reporting_airline) AS ids_dot,
       array_agg(DISTINCT dot_id_reporting_airline) AS valores
FROM staging.vuelos
GROUP BY reporting_airline
HAVING count(DISTINCT dot_id_reporting_airline) > 1;

-- ---------------------------------------------------------------------
-- 6. Columnas redundantes
-- ---------------------------------------------------------------------
-- 6a. Columnas constantes (un solo valor o solo nulos)
SELECT columna, distintos, nulos, total
FROM staging.perfil_vuelos
WHERE es_constante
ORDER BY columna;

-- 6b. Pares de columnas equivalentes: si distintos_a = distintos_b = combinaciones,
--     las dos columnas dicen lo mismo y una sobra.
SELECT 'origin / originairportid' AS par,
       count(DISTINCT origin) AS distintos_a,
       count(DISTINCT originairportid) AS distintos_b,
       count(DISTINCT (origin, originairportid)) AS combinaciones
FROM staging.vuelos
UNION ALL
SELECT 'dest / destairportid',
       count(DISTINCT dest), count(DISTINCT destairportid),
       count(DISTINCT (dest, destairportid))
FROM staging.vuelos
UNION ALL
SELECT 'originstate / originstatefips',
       count(DISTINCT originstate), count(DISTINCT originstatefips),
       count(DISTINCT (originstate, originstatefips))
FROM staging.vuelos
UNION ALL
SELECT 'originstate / originstatename',
       count(DISTINCT originstate), count(DISTINCT originstatename),
       count(DISTINCT (originstate, originstatename))
FROM staging.vuelos
UNION ALL
SELECT 'deststate / deststatename',
       count(DISTINCT deststate), count(DISTINCT deststatename),
       count(DISTINCT (deststate, deststatename))
FROM staging.vuelos
UNION ALL
SELECT 'reporting_airline / dot_id_reporting_airline',
       count(DISTINCT reporting_airline), count(DISTINCT dot_id_reporting_airline),
       count(DISTINCT (reporting_airline, dot_id_reporting_airline))
FROM staging.vuelos
UNION ALL
SELECT 'reporting_airline / iata_code_reporting_airline',
       count(DISTINCT reporting_airline), count(DISTINCT iata_code_reporting_airline),
       count(DISTINCT (reporting_airline, iata_code_reporting_airline))
FROM staging.vuelos;

-- 6c. Columnas derivables de otras: year, quarter, month, dayofmonth y dayofweek
--     se pueden calcular a partir de flightdate. Casos donde NO coinciden:
SELECT count(*) AS filas_que_no_coinciden
FROM staging.vuelos
WHERE extract(year FROM flightdate)  <> year
   OR extract(month FROM flightdate) <> month
   OR extract(day FROM flightdate)   <> dayofmonth
   OR extract(quarter FROM flightdate) <> quarter
   OR extract(isodow FROM flightdate)  <> dayofweek;

-- 6d. depdelayminutes es depdelay con los negativos en cero
SELECT count(*) AS filas_que_no_coinciden
FROM staging.vuelos
WHERE depdelay IS NOT NULL
  AND depdelayminutes IS DISTINCT FROM greatest(depdelay, 0);

-- ---------------------------------------------------------------------
-- 7. Distribucion de registros por categoria
-- ---------------------------------------------------------------------
SELECT reporting_airline, count(*) AS vuelos
FROM staging.vuelos GROUP BY reporting_airline ORDER BY vuelos DESC;

SELECT origin, origincityname, count(*) AS vuelos
FROM staging.vuelos GROUP BY origin, origincityname ORDER BY vuelos DESC LIMIT 20;

SELECT dest, destcityname, count(*) AS vuelos
FROM staging.vuelos GROUP BY dest, destcityname ORDER BY vuelos DESC LIMIT 20;

SELECT originstate, count(*) AS vuelos
FROM staging.vuelos GROUP BY originstate ORDER BY vuelos DESC LIMIT 20;

SELECT month, count(*) AS vuelos
FROM staging.vuelos GROUP BY month ORDER BY month;

SELECT dayofweek, count(*) AS vuelos
FROM staging.vuelos GROUP BY dayofweek ORDER BY dayofweek;

SELECT cancelled, diverted, count(*) AS vuelos
FROM staging.vuelos GROUP BY cancelled, diverted ORDER BY cancelled, diverted;

SELECT cancellationcode, count(*) AS vuelos
FROM staging.vuelos GROUP BY cancellationcode ORDER BY vuelos DESC;

SELECT depdel15, count(*) AS vuelos
FROM staging.vuelos GROUP BY depdel15 ORDER BY depdel15;

-- ---------------------------------------------------------------------
-- 8. Valores nulos por columna
-- ---------------------------------------------------------------------
SELECT columna, tipo, nulos, pct_nulos
FROM staging.perfil_vuelos
WHERE nulos > 0
ORDER BY nulos DESC, columna;

-- Muchos nulos son esperados: un vuelo cancelado no tiene hora real de salida
SELECT cancelled,
       count(*)                                          AS vuelos,
       count(*) FILTER (WHERE deptime IS NULL)           AS sin_deptime,
       count(*) FILTER (WHERE arrdelay IS NULL)          AS sin_arrdelay,
       count(*) FILTER (WHERE carrierdelay IS NULL)      AS sin_causa_de_retraso
FROM staging.vuelos
GROUP BY cancelled
ORDER BY cancelled;

-- ---------------------------------------------------------------------
-- 9. Inconsistencias: cada regla devuelve cuantos registros la incumplen
-- ---------------------------------------------------------------------
SELECT 'cancelado con hora real de salida' AS regla, count(*) AS casos
FROM staging.vuelos WHERE cancelled = 1 AND deptime IS NOT NULL
UNION ALL
SELECT 'no cancelado sin hora real de salida', count(*)
FROM staging.vuelos WHERE cancelled = 0 AND deptime IS NULL
UNION ALL
SELECT 'cancelado sin codigo de cancelacion', count(*)
FROM staging.vuelos WHERE cancelled = 1 AND cancellationcode IS NULL
UNION ALL
SELECT 'codigo de cancelacion en vuelo no cancelado', count(*)
FROM staging.vuelos WHERE cancelled = 0 AND cancellationcode IS NOT NULL
UNION ALL
SELECT 'cancelado y desviado a la vez', count(*)
FROM staging.vuelos WHERE cancelled = 1 AND diverted = 1
UNION ALL
SELECT 'origen igual a destino', count(*)
FROM staging.vuelos WHERE origin = dest
UNION ALL
SELECT 'distancia menor o igual a cero', count(*)
FROM staging.vuelos WHERE distance <= 0
UNION ALL
SELECT 'tiempo en aire mayor al tiempo total', count(*)
FROM staging.vuelos WHERE airtime > actualelapsedtime
UNION ALL
SELECT 'tiempos de taxi negativos', count(*)
FROM staging.vuelos WHERE taxiout < 0 OR taxiin < 0
UNION ALL
SELECT 'depdel15 no coincide con depdelay', count(*)
FROM staging.vuelos
WHERE depdelay IS NOT NULL
  AND ((depdelay >= 15 AND depdel15 <> 1) OR (depdelay < 15 AND depdel15 <> 0))
UNION ALL
SELECT 'causas de retraso no suman arrdelay', count(*)
FROM staging.vuelos
WHERE carrierdelay IS NOT NULL
  AND carrierdelay + weatherdelay + nasdelay + securitydelay + lateaircraftdelay <> arrdelay
UNION ALL
SELECT 'numero de matricula (tail_number) vacio', count(*)
FROM staging.vuelos WHERE tail_number IS NULL;
