# Festivos colombianos y cálculo de transporte

Este documento especifica las dos reglas de negocio más particulares del proyecto.

## 1. Festivos de Colombia

Colombia tiene **18 festivos al año**, regidos por la **Ley 51 de 1983** (conocida como *Ley
Emiliani*), que traslada varios de ellos al lunes siguiente para generar puentes.

Se calculan en el backend de forma determinista, sin depender de servicios externos, y se
exponen vía API para que el cliente los muestre en el calendario.

### 1.1 Festivos de fecha fija (6)

No se trasladan nunca, sin importar en qué día caigan.

| Fecha | Festivo |
|---|---|
| 1 de enero | Año Nuevo |
| 1 de mayo | Día del Trabajo |
| 20 de julio | Día de la Independencia |
| 7 de agosto | Batalla de Boyacá |
| 8 de diciembre | Inmaculada Concepción |
| 25 de diciembre | Navidad |

### 1.2 Festivos trasladables — Ley Emiliani (7)

Si no caen en lunes, se trasladan al **lunes inmediatamente siguiente**.

| Fecha base | Festivo |
|---|---|
| 6 de enero | Reyes Magos |
| 19 de marzo | San José |
| 29 de junio | San Pedro y San Pablo |
| 15 de agosto | Asunción de la Virgen |
| 12 de octubre | Día de la Raza |
| 1 de noviembre | Todos los Santos |
| 11 de noviembre | Independencia de Cartagena |

### 1.3 Festivos derivados de la Pascua (5)

Se calculan a partir del Domingo de Resurrección.

| Desplazamiento | Festivo | ¿Se traslada? |
|---|---|---|
| Pascua − 3 días | Jueves Santo | No (cae jueves) |
| Pascua − 2 días | Viernes Santo | No (cae viernes) |
| Pascua + 43 días | Ascensión de Jesús | Ya trasladado (cae lunes) |
| Pascua + 64 días | Corpus Christi | Ya trasladado (cae lunes) |
| Pascua + 71 días | Sagrado Corazón de Jesús | Ya trasladado (cae lunes) |

Los desplazamientos +43, +64 y +71 ya incorporan el traslado al lunes previsto por la Ley
Emiliani (las fechas litúrgicas originales son +39, +60 y +68).

### 1.4 Algoritmo del Domingo de Resurrección

Se usa el **algoritmo de Meeus/Butcher** para el calendario gregoriano:

```
a = año mod 19
b = año / 100            (división entera)
c = año mod 100
d = b / 4
e = b mod 4
f = (b + 8) / 25
g = (b - f + 1) / 3
h = (19a + b - d - g + 15) mod 30
i = c / 4
k = c mod 4
l = (32 + 2e + 2i - h - k) mod 7
m = (a + 11h + 22l) / 451

mes  = (h + l - 7m + 114) / 31
día  = ((h + l - 7m + 114) mod 31) + 1
```

**Verificación para 2026** — Domingo de Resurrección: **5 de abril de 2026**.

| Festivo | Fecha resultante | Día |
|---|---|---|
| Jueves Santo | 2 de abril | jueves |
| Viernes Santo | 3 de abril | viernes |
| Ascensión | 18 de mayo | lunes |
| Corpus Christi | 8 de junio | lunes |
| Sagrado Corazón | 15 de junio | lunes |

### 1.5 Implementación

```java
public interface HolidayCalculator {
    List<Holiday> forYear(int year);
    List<Holiday> forMonth(YearMonth month);
    boolean isHoliday(LocalDate date);
}
```

El resultado se cachea en memoria por año, dado que es una función pura del año.

---

## 2. Motor de cálculo de transporte

El objetivo es responder: **¿cuánto voy a gastar en transporte este mes?**, contando los días
en que realmente hay que desplazarse.

### 2.1 Parámetros configurables por mes

| Parámetro | Descripción | Valor por defecto |
|---|---|---|
| `valorPasaje` | Costo de un pasaje sencillo | — (editable) |
| `pasajesDiaOficina` | Pasajes en un día normal de oficina | 2 (ida y vuelta) |
| `pasajesExtraKarate` | Pasajes adicionales si hay karate ese día | 1 |
| `pasajesKarateDesdeCasa` | Pasajes si hay karate en un día remoto o no laboral | 2 |
| `diasLaborales` | Días de la semana que se trabaja | lunes a viernes |
| `diasKarate` | Días de la semana con clase de karate | configurable |
| `diasRemotosPorSemana` | Estimación inicial de días remotos | 1 |

Todos los valores son editables porque pueden cambiar mes a mes.

### 2.2 Clasificación de días

Cada día del mes recibe un tipo. La app precalcula una propuesta y el usuario la ajusta en un
calendario interactivo.

| Tipo | Origen | Pasajes |
|---|---|---|
| `FIN_DE_SEMANA` | automático | 0 (salvo karate) |
| `FESTIVO` | automático (Ley Emiliani) | 0 (salvo karate) |
| `OFICINA` | por defecto en días laborales | `pasajesDiaOficina` |
| `REMOTO` | marcado por el usuario | 0 (salvo karate) |
| `VACACIONES` | marcado por el usuario | 0 |
| `AUSENTE` | incapacidad, permiso | 0 |

### 2.3 Fórmula de pasajes por día

```
si tipo ∈ {VACACIONES, AUSENTE}:
    pasajes = 0

si tipo == OFICINA:
    pasajes = pasajesDiaOficina + (hayKarate ? pasajesExtraKarate : 0)

si tipo ∈ {REMOTO, FESTIVO, FIN_DE_SEMANA}:
    pasajes = hayKarate ? pasajesKarateDesdeCasa : 0

si el día tiene override manual:
    pasajes = valor indicado por el usuario
```

**Total del mes** = `Σ pasajes(día) × valorPasaje`

El razonamiento detrás de `pasajesKarateDesdeCasa`: en un día de trabajo remoto igual hay que
desplazarse a la clase de karate y volver, lo que cuesta dos pasajes en lugar del pasaje
adicional que costaría saliendo desde la oficina.

### 2.4 Escenarios comparativos

Como los días remotos varían ("uno seguro, a veces dos"), la app muestra tres proyecciones
simultáneas para saber en qué rango se moverá el gasto:

| Escenario | Supuesto |
|---|---|
| Optimista | 2 días remotos por semana |
| Esperado | 1 día remoto por semana |
| Pesimista | 0 días remotos (todo presencial) |

### 2.5 Seguimiento contra lo real

El cálculo se hace al inicio del mes, pero la realidad cambia. La app permite ir marcando los
días conforme ocurren y compara **presupuestado vs. real**, mostrando la desviación acumulada
y proyectando el cierre del mes con los días restantes.

### 2.6 Interfaz

Un calendario mensual donde cada día se pinta según su tipo, con festivos y fines de semana
ya resueltos. Un toque cambia el tipo del día; el total se recalcula al instante en el
cliente, sin ida y vuelta al servidor.

```
        Agosto 2026
 Lu  Ma  Mi  Ju  Vi  Sa  Do
                      1   2
  3   4   5   6   7*  8   9      * 7 ago — Batalla de Boyacá
 10  11  12  13  14  15  16
 17* 18  19  20  21  22  23      * 17 ago — Asunción (trasladado del 15)
 24  25  26  27  28  29  30
 31

 ■ oficina   □ remoto   ▲ festivo   · fin de semana
```
