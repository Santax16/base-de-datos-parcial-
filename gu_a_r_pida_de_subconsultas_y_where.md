# Guía Rápida: ¿Qué Subconsulta Uso?

Para decidir al instante en el examen, mirá **qué pregunta querés responder** y **en qué parte de la consulta estás parado**.

---

## 1. Subconsulta Escalar ("Normal": devuelve 1 solo dato)
Se usa cuando preguntás **"¿Cuál es el valor...?"** o **"¿Cuánto...?"**. Devuelve exactamente **1 fila y 1 columna**.

* **¿Dónde va?** 
  * En el **`SELECT`** (el *mandadero* que trae una columna calculada).
  * En el **`WHERE`** comparando con `=`, `>`, `<`, `>=`, `<=`.
* **Señales en el enunciado:**
  * *"Mostrar la cantidad de..."*, *"El importe total..."*, *"La fecha de última compra..."*
  * *"El que más..."* / *"El período con mayor..."* $\rightarrow$ lleva `SELECT TOP 1 ... ORDER BY ... DESC` (Receta 1).
  * *"Que hayan comprado más de 10.000 unidades..."* $\rightarrow$ `WHERE (SELECT SUM(...) ...) > 10000`.
* **Ejemplos en GESTION2016:**
  ```sql
  -- En el SELECT (siempre envolver con ISNULL afuera por si vuelve vacío)
  ISNULL((
      SELECT SUM(f.fact_total) 
      FROM Factura f 
      WHERE f.fact_cliente = c.clie_codigo
  ), 0) AS monto_total

  -- En el WHERE (comparando contra un número)
  WHERE (
      SELECT COUNT(*) 
      FROM Factura f 
      WHERE f.fact_cliente = c.clie_codigo 
        AND YEAR(f.fact_fecha) = 2012
  ) >= 100
  ```

---

## 2. Subconsulta con `WHERE EXISTS` / `NOT EXISTS` (De existencia)
Se usa cuando preguntás **"¿Tiene o no tiene...?"**. No importa *cuántos* ni *qué valor*; solo importa **si existe al menos una fila** que cumpla la condición (devuelve Verdadero o Falso y no lleva nada a memoria).

* **¿Dónde va?** En el **`WHERE`** (o adentro de un `CASE WHEN EXISTS (...)` para ordenar/etiquetar).
* **Señales en el enunciado:**
  * *"Que posean stock..."*, *"Que hayan comprado en 2011..."* $\rightarrow$ **`WHERE EXISTS (SELECT 1 ...)`**
  * *"Que NUNCA hayan comprado..."*, *"Sin facturas..."*, *"Solo productos compuestos..."* (doble negación) $\rightarrow$ **`WHERE NOT EXISTS (SELECT 1 ...)`**
* **⚠️ Trampa mortal a evitar:** Nunca metas un `SUM` o `COUNT` sin `GROUP BY` adentro de un `EXISTS`, porque un agregado sin agrupar siempre devuelve 1 fila (aunque sea `0` o `NULL`) y el `EXISTS` te va a dar **siempre verdadero**.
* **Ejemplos en GESTION2016:**
  ```sql
  -- Positivo: productos que tienen stock mayor a 0 en algún depósito
  WHERE EXISTS (
      SELECT 1 
      FROM STOCK s 
      WHERE s.stoc_producto = p.prod_codigo 
        AND s.stoc_cantidad > 0
  )

  -- Negado: clientes que NUNCA compraron un producto compuesto
  WHERE NOT EXISTS (
      SELECT 1
      FROM Factura f
      JOIN Item_Factura i 
          ON i.item_tipo = f.fact_tipo 
         AND i.item_sucursal = f.fact_sucursal 
         AND i.item_numero = f.fact_numero
      JOIN Composicion co 
          ON co.comp_producto = i.item_producto
      WHERE f.fact_cliente = c.clie_codigo
  )
  ```

---

## 3. Las otras dos variantes del `WHERE`

| Si el enunciado dice... | Qué escribís | Qué devuelve adentro |
| :--- | :--- | :--- |
| **"Está dentro de una lista"** o **"Los N primeros..."** *(ej: "De los 10 que más facturaron...")* | `WHERE col IN (SELECT TOP 10 ...)` *(o `NOT IN`)* | **1 sola columna** y de `0` a `N` filas. *(Nota: `NOT IN` falla si la subconsulta trae algún `NULL`; ahí conviene `NOT EXISTS`).* |
| **"En todos los..."** *(ej: "Stock en todos los depósitos")* | `HAVING COUNT(DISTINCT col) = (SELECT COUNT(*) FROM Tabla)` | **1 número total** para comparar contra el universo completo (Receta 3). |

---

## Resumen de 5 segundos antes de escribir
1. ¿Querés **mostrar un dato** en una columna o compararlo con `>` / `=`? $\rightarrow$ **Subconsulta escalar** `(SELECT ...)`.
2. ¿Querés **filtrar** porque *"tiene / no tiene / alguna vez / nunca"*? $\rightarrow$ **`EXISTS` / `NOT EXISTS`**.
3. ¿Querés **filtrar contra un ranking** (*"los top 10..."*)? $\rightarrow$ **`IN (SELECT TOP 10 ...)`**.