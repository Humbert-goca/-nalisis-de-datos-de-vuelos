# Proyecto Final — Bases de Datos (COM-12101-001, Primavera 2026)

# Etapa 1: Selección del conjunto de datos

**Tema:** Retrasos y cancelaciones de vuelos comerciales en Estados Unidos
**Equipo:** Humberto Gómez Calderon, Giovanna del Rosario Rodríguez Carrillo
**Organización / repositorio:** https://www.bts.gov| https://github.com/Humbert-goca/-nalisis-de-datos-de-vuelos

---

## 1. Enlaces directos al conjunto de datos original

| Recurso | Enlace |
|---|---|
| Ficha oficial de la base de datos (BTS TranStats) | <https://www.transtats.bts.gov/DatabaseInfo.asp?QO_VQ=EFD> |
| Tabla utilizada | *Reporting Carrier On-Time Performance (1987-present)* |
| Archivo descargado | `On_Time_Reporting_Carrier_On_Time_Performance_(1987_present)_2024_3.csv` (marzo de 2024) |
| Fecha de descarga | **21 de noviembre del 2026** |

El archivo se obtuvo con **Download → Prezipped File** en la página de la tabla, eligiendo año 2024 y mes 3.

---

## 2. Descripción del conjunto de datos

### Resumen
Registro, vuelo por vuelo, del desempeño de los vuelos domésticos nacionales sin escalas operados por las aerolíneas de Estados Unidos. Cada fila es **un vuelo** e incluye horarios programados y reales de salida y llegada, retrasos, tiempos de rodaje (taxi), vuelos cancelados y desviados, causas de retraso y cancelación, distancia, y los datos del avión, la aerolínea y los aeropuertos de origen y destino.

Para el proyecto se usa **un mes** de la serie (marzo de 2024), que ya supera con amplitud los requisitos del curso.

### Origen y autoría
La información la recopila la **Oficina de Estadísticas de Transporte** (*Bureau of Transportation Statistics*, BTS), que forma parte del Departamento de Transporte de EE. UU. (DOT). Dentro del BTS, la oficina responsable es la *Office of Airline Information*. Los datos los reportan las propias aerolíneas: la ficha oficial indica que cubre a las aerolíneas certificadas en EE. UU. que representan **al menos 0.5 % de los ingresos por pasajeros en vuelos nacionales programados**; además, algunas aerolíneas reportan de forma voluntaria.

### Justificación
La ficha del BTS no declara de forma explícita el propósito de esta base de datos. En general, el BTS ofrece estadísticas de transporte para dar contexto a quienes toman decisiones y al público. Estos datos permiten medir la puntualidad y la calidad del servicio de las aerolíneas y los aeropuertos, y el DOT los utiliza en sus informes mensuales de servicio al consumidor aéreo (*Air Travel Consumer Report*). A los miembros del equipo nos pareció interesante el poder comparar y medir la calidad de las distintas aerolíneas, saber cuántos vuelos salen en tiempo realmente o qué tan raro es que un vuelo sea cancelado. 

### Disponibilidad y acceso
Se aloja en el portal **BTS TranStats** (<https://www.transtats.bts.gov>), de acceso público y gratuito, sin registro. Se puede descargar por mes en un archivo comprimido con un CSV, o elegir columnas en la propia página. 

### Periodicidad de actualización
**Mensual.** La ficha indica frecuencia mensual y cobertura desde **1987 hasta 2026**. Cada mes se publica un archivo nuevo, con un desfase respecto al periodo que cubre. La ficha enlaza a una página de *Upcoming Releases* con las próximas publicaciones, pero no indica un calendario exacto. 

### Dimensiones
| Concepto | Valor |
|---|---|
| Registros (filas) | **591,767** |
| Variables (columnas) | **109** |
| Periodo cubierto | Marzo de 2024 |
| Columnas añadidas al cargar | `id_raw` (consecutivo) y `archivo_origen` (nombre del CSV) |

Los CSV del BTS terminan cada línea con una coma, lo que genera una columna final vacía que el script de carga elimina. Los valores anteriores se obtuvieron de la tabla `staging.vuelos_raw`.

### Por qué cumple los requisitos del curso
| Requisito | Cumplimiento |
|---|---|
| Relevancia | Datos reales y oficiales del DOT. **[COMPLETAR: interés del equipo]** |
| Estructura (≥ 5 entidades) | Aerolínea, avión (matrícula), aeropuerto, ciudad/estado, vuelo, causa de retraso o cancelación |
| Tamaño (≥ 5,000 registros) | 591,767 |
| Atributos (≥ 15) | 109 |
| Estado (desnormalizado) | Una sola tabla plana: los datos de aerolíneas y aeropuertos se repiten en cada vuelo (por ejemplo, ciudad, estado, FIPS y WAC se repiten para cada vuelo del mismo aeropuerto) |

### Diccionario de datos
Las definiciones siguen la documentación del BTS. Los nombres coinciden con las columnas del archivo. Las horas están en formato `hhmm` y en **hora local** del aeropuerto correspondiente.

> Para verificar que la lista coincide con tu archivo, ejecuta en DBeaver:
> `SELECT column_name FROM information_schema.columns WHERE table_schema='staging' AND table_name='vuelos_raw' ORDER BY ordinal_position;`

#### Periodo
| Campo | Descripción |
|---|---|
| `Year` | Año |
| `Quarter` | Trimestre (1-4) |
| `Month` | Mes (1-12) |
| `DayofMonth` | Día del mes |
| `DayOfWeek` | Día de la semana (1 = lunes … 7 = domingo) |
| `FlightDate` | Fecha del vuelo (aaaa-mm-dd) |

#### Aerolínea y avión
| Campo | Descripción |
|---|---|
| `Reporting_Airline` | Código único de la aerolínea que reporta (úsese para análisis a través del tiempo) |
| `DOT_ID_Reporting_Airline` | Identificador numérico asignado por el DOT a la aerolínea |
| `IATA_CODE_Reporting_Airline` | Código IATA de la aerolínea |
| `Tail_Number` | Matrícula del avión |
| `Flight_Number_Reporting_Airline` | Número de vuelo |

#### Aeropuerto de origen (`Origin*`) y de destino (`Dest*`)
Los dos grupos tienen los mismos campos; aquí se muestra el de origen. Para el destino, cambia el prefijo `Origin` por `Dest`.

| Campo | Descripción |
|---|---|
| `OriginAirportID` | Identificador numérico del aeropuerto (DOT) |
| `OriginAirportSeqID` | Identificador de secuencia del aeropuerto (identifica al aeropuerto en un momento dado) |
| `OriginCityMarketID` | Identificador del mercado de la ciudad (agrupa los aeropuertos de una misma ciudad) |
| `Origin` | Código IATA del aeropuerto (3 letras) |
| `OriginCityName` | Ciudad y estado (formato "Ciudad, ST") |
| `OriginState` | Abreviatura del estado |
| `OriginStateFips` | Código FIPS del estado |
| `OriginStateName` | Nombre del estado |
| `OriginWac` | *World Area Code* del estado |

#### Salida
| Campo | Descripción |
|---|---|
| `CRSDepTime` | Hora de salida programada (hhmm) |
| `DepTime` | Hora de salida real (hhmm) |
| `DepDelay` | Retraso en la salida, en minutos (negativo = salió antes) |
| `DepDelayMinutes` | Retraso en la salida en minutos, con los adelantos en 0 |
| `DepDel15` | Indicador: 1 si el retraso en la salida es de 15 minutos o más |
| `DepartureDelayGroups` | Grupo de retraso en la salida, en intervalos de 15 minutos |
| `DepTimeBlk` | Bloque horario de una hora de la salida programada |
| `TaxiOut` | Minutos de rodaje desde la puerta hasta el despegue |
| `WheelsOff` | Hora del despegue (hhmm) |

#### Llegada
| Campo | Descripción |
|---|---|
| `WheelsOn` | Hora del aterrizaje (hhmm) |
| `TaxiIn` | Minutos de rodaje desde el aterrizaje hasta la puerta |
| `CRSArrTime` | Hora de llegada programada (hhmm) |
| `ArrTime` | Hora de llegada real (hhmm) |
| `ArrDelay` | Retraso en la llegada, en minutos (negativo = llegó antes) |
| `ArrDelayMinutes` | Retraso en la llegada en minutos, con los adelantos en 0 |
| `ArrDel15` | Indicador: 1 si el retraso en la llegada es de 15 minutos o más |
| `ArrivalDelayGroups` | Grupo de retraso en la llegada, en intervalos de 15 minutos |
| `ArrTimeBlk` | Bloque horario de una hora de la llegada programada |

#### Cancelaciones y desvíos
| Campo | Descripción |
|---|---|
| `Cancelled` | Indicador: 1 si el vuelo fue cancelado |
| `CancellationCode` | Motivo de la cancelación: A = aerolínea, B = clima, C = sistema nacional de aviación (NAS), D = seguridad |
| `Diverted` | Indicador: 1 si el vuelo fue desviado |

#### Duración y distancia
| Campo | Descripción |
|---|---|
| `CRSElapsedTime` | Duración programada del vuelo, en minutos |
| `ActualElapsedTime` | Duración real del vuelo, en minutos |
| `AirTime` | Tiempo en el aire, en minutos |
| `Flights` | Número de vuelos (1 en cada fila) |
| `Distance` | Distancia entre aeropuertos, en millas |
| `DistanceGroup` | Grupo de distancia, en intervalos de 250 millas |

#### Causas de retraso
Solo tienen valor cuando el retraso en la llegada es de 15 minutos o más. Se expresan en minutos.

| Campo | Descripción |
|---|---|
| `CarrierDelay` | Retraso atribuible a la aerolínea |
| `WeatherDelay` | Retraso por clima extremo |
| `NASDelay` | Retraso por el sistema nacional de aviación (control de tráfico, volumen de operaciones, etc.) |
| `SecurityDelay` | Retraso por seguridad |
| `LateAircraftDelay` | Retraso por la llegada tardía del avión de un vuelo anterior |

#### Desvíos
| Campo | Descripción |
|---|---|
| `FirstDepTime` | Primera hora real de salida de la puerta, en vuelos con cambio de puerta |
| `TotalAddGTime` | Tiempo total adicional en tierra, en minutos |
| `LongestAddGTime` | Mayor tiempo adicional en tierra, en minutos |
| `DivAirportLandings` | Número de aterrizajes por desvío |
| `DivReachedDest` | Indicador: 1 si el vuelo desviado llegó a su destino |
| `DivActualElapsedTime` | Duración real del vuelo desviado, en minutos |
| `DivArrDelay` | Retraso en la llegada del vuelo desviado, en minutos |
| `DivDistance` | Distancia entre el destino programado y el último aeropuerto del desvío, en millas |

Para cada uno de los desvíos `N = 1, 2, 3, 4, 5` (40 columnas en total):

| Campo | Descripción |
|---|---|
| `DivNAirport` | Código del aeropuerto del desvío N |
| `DivNAirportID` | Identificador del aeropuerto |
| `DivNAirportSeqID` | Identificador de secuencia del aeropuerto |
| `DivNWheelsOn` | Hora de aterrizaje (hhmm) |
| `DivNTotalGTime` | Tiempo total en tierra, en minutos |
| `DivNLongestGTime` | Mayor tiempo en tierra, en minutos |
| `DivNWheelsOff` | Hora de despegue (hhmm) |
| `DivNTailNum` | Matrícula del avión en ese tramo |

### Variables cuantitativas
Atributos de naturaleza numérica (minutos, millas o conteos):

- Retrasos: `DepDelay`, `DepDelayMinutes`, `ArrDelay`, `ArrDelayMinutes`
- Causas de retraso: `CarrierDelay`, `WeatherDelay`, `NASDelay`, `SecurityDelay`, `LateAircraftDelay`
- Tiempos de operación: `TaxiOut`, `TaxiIn`, `CRSElapsedTime`, `ActualElapsedTime`, `AirTime`
- Distancia y conteos: `Distance`, `Flights`, `DivAirportLandings`
- Desvíos: `TotalAddGTime`, `LongestAddGTime`, `DivActualElapsedTime`, `DivArrDelay`, `DivDistance`, `DivNTotalGTime`, `DivNLongestGTime`

Los grupos (`DistanceGroup`, `DepartureDelayGroups`, `ArrivalDelayGroups`) son categorías ordinales con código numérico.

### Variables cualitativas
Atributos que representan categorías o etiquetas:

- **Aerolínea y avión:** `Reporting_Airline`, `DOT_ID_Reporting_Airline`, `IATA_CODE_Reporting_Airline`, `Tail_Number`, `Flight_Number_Reporting_Airline`
- **Aeropuertos y lugares:** `Origin`, `Dest`, los identificadores (`*AirportID`, `*AirportSeqID`, `*CityMarketID`), `*CityName`, `*State`, `*StateFips`, `*StateName`, `*Wac`, y `DivNAirport`
- **Indicadores (0/1):** `Cancelled`, `Diverted`, `DepDel15`, `ArrDel15`, `DivReachedDest`
- **Códigos:** `CancellationCode`
- **Categorías ordinales:** `DistanceGroup`, `DepartureDelayGroups`, `ArrivalDelayGroups`, `DepTimeBlk`, `ArrTimeBlk`

### Texto no estructurado
**No hay columnas de texto libre.** El campo más parecido es `*CityName` ("Ciudad, ST"), que es texto con formato fijo, y `Tail_Number`, que es un código.

### Series temporales
- **Fecha:** `FlightDate`, junto con `Year`, `Quarter`, `Month`, `DayofMonth` y `DayOfWeek`
- **Horas del día (hhmm, hora local):** `CRSDepTime`, `DepTime`, `WheelsOff`, `WheelsOn`, `CRSArrTime`, `ArrTime`, `FirstDepTime`, `DivNWheelsOn`, `DivNWheelsOff`
- **Bloques horarios:** `DepTimeBlk`, `ArrTimeBlk`

Como el archivo cubre un solo mes, la serie temporal se limita a los días de marzo de 2024. La fuente permite ampliar el análisis a otros meses y años.

### Visión estratégica
**Objetivo principal:** analizar los patrones de retrasos y cancelaciones de los vuelos comerciales en EE. UU. y entender de qué dependen. 

Preguntas que guiarán el análisis (ejemplos):
- ¿Qué aerolíneas y qué aeropuertos tienen mayor proporción de retrasos y cancelaciones?
- ¿Cómo cambian los retrasos según el día de la semana y la hora de salida?
- ¿Qué causas explican la mayor parte de los minutos de retraso (aerolínea, clima, sistema nacional, seguridad, avión anterior)?
- ¿Cuáles son las rutas más afectadas?

**Cómo se implementará**, en las etapas siguientes y usando exclusivamente SQL:
1. **Etapa 2:** carga a tablas de staging, limpieza y análisis exploratorio.
2. **Etapa 3:** normalización hasta 4NF (aerolíneas, aviones, aeropuertos, ubicaciones, vuelos, causas) y diagrama entidad-relación.
3. **Etapa 4:** consultas avanzadas con filtros, agrupamientos, agregaciones y funciones de ventana sobre el esquema normalizado.
4. **Etapa 5:** API REST con FastAPI para operaciones CRUD sobre las tablas normalizadas.

### Consideraciones éticas
- **Datos personales:** el conjunto no contiene datos de pasajeros ni de tripulación; son datos operativos a nivel de vuelo. La matrícula (`Tail_Number`) identifica aeronaves, no personas.
- **Reputación de empresas:** los resultados señalan aerolíneas y aeropuertos concretos. Las comparaciones deben presentarse con cuidado y contexto, porque pueden afectar la imagen de las organizaciones.
- **Sesgo de cobertura:** solo incluye vuelos nacionales sin escalas de las aerolíneas que reportan (las que alcanzan el umbral de ingresos o reportan voluntariamente). No representa a toda la aviación de EE. UU. ni a los vuelos internacionales.
- **Datos autorreportados:** las propias aerolíneas reportan los horarios y las causas de retraso, por lo que la clasificación de causas puede tener sesgos o inconsistencias.
- **Comparaciones injustas:** una aerolínea con más conexiones en aeropuertos saturados o con rutas de otro tipo puede parecer peor sin serlo. Conviene controlar por ruta, aeropuerto y época del año.
- **Valores nulos:** los vuelos cancelados no tienen horas reales, y las causas de retraso solo existen cuando el retraso en la llegada es de 15 minutos o más. Ignorarlo distorsiona los promedios.
- **Alcance temporal:** un solo mes puede reflejar condiciones particulares (clima, eventos) y no generalizarse a todo el año.
- **Licencia y uso:** son datos públicos del gobierno de EE. UU., sin restricciones de uso para un proyecto académico. 

---

## Referencias
- Bureau of Transportation Statistics. *Airline On-Time Performance Data*. <https://www.transtats.bts.gov/DatabaseInfo.asp?QO_VQ=EFD>
