# Gestión de Datos (GDD) — Cheat Sheet Oficial de Examen

Guía definitiva de patrones, reglas de reconocimiento y plantillas de código para rendir exámenes de **SQL DML** y **T-SQL** en SQL Server Management Studio (SSMS).

---

## 🧭 Tabla Rápida: De la Frase del Enunciado al Molde Técnico

### 1. Consultas SQL Puro (DML)
| Frase en el Enunciado | Significado Técnico | Solución / Patrón |
| :--- | :--- | :--- |
| **"No se permiten sub-selects en el FROM ni CTEs"** | Prohibido usar tablas derivadas temporales en el `FROM`. | **Subconsultas correlacionadas escalares en el `SELECT`**. |
| **"El período (AAAAMM) con mayor..."** / **"El cliente que más..."** | Ranking local por fila o grupo sin usar ventana. | `(SELECT TOP 1 clave FROM ... WHERE fk = p.pk GROUP BY clave ORDER BY SUM(...) DESC)` |
| **"Pares de productos/familias vendidos juntos... no retornarse más de una vez"** | Comparar dos ítems de una misma factura evitando duplicados espejo ($A-B$ y $B-A$). | **Self-Join** con desigualdad estricta: `JOIN Item_Factura i2 ON ... AND i1.item_producto > i2.item_producto` |
| **"Número de fila (orden correlativo empezando en 1)"** | Numeración ordinal de la grilla de salida. | `ROW_NUMBER() OVER (ORDER BY columna ASC) AS nro_fila` |
| **"Porcentaje respecto del total del año/período"** | Proporción de la fila actual contra el gran total. | `CAST((SUM(cant) * 100.0) / (SELECT SUM(cant) FROM Factura/Item WHERE ...) AS DECIMAL(10,2))` |
| **"Ningún dato del resultado puede ser NULL"** | Evitar nulos generados por subconsultas vacías o `LEFT JOIN`. | `ISNULL(expresion, 0)` o `ISNULL(expresion, 'SIN DATO')` |
| **"Años consecutivos (> 2020)"** | Ventas en una cadena ininterrumpida de años sin hardcodear. | `EXISTS` con `YEAR(f1) > 2020` y sub-`EXISTS` con `YEAR = YEAR(f1) + 1` |

### 2. Procedural y Triggers (T-SQL)
| Frase en el Enunciado | Significado Técnico | Solución / Patrón |
| :--- | :--- | :--- |
| **"Verifique que...", "No permitir que...", "Rechazar operación..."** | Validación de integridad o reglas de negocio que abortan. | **Molde 1 (Validación):** `IF EXISTS (...) BEGIN RAISERROR(...) ROLLBACK TRAN RETURN END` |
| **"Descontar del stock los artículos vendidos..."** | Actualización masiva de saldos por operaciones DML. | **Molde 2 (Consistencia):** `UPDATE s FROM STOCK s JOIN (SELECT id, SUM(cant) FROM inserted GROUP BY id) lote ...` |
| **"Mantener permanentemente actualizada una tabla resumen en tiempo real..."** | Tabla histórica o acumulador sincronizado ante altas, bajas o modificaciones. | **Molde 3 (Acumulados con MERGE):** Tabla `@afectados` uniendo `inserted` + `deleted`, seguido de `MERGE INTO ... USING ... ON ...` |
| **"En una sola transacción se realice la actualización del stock y llenado de tablas..."** | Atomicidad entre múltiples escrituras de tablas distintas. | **Molde 4 (Stored Procedure Transaccional):** `BEGIN TRY BEGIN TRAN ... COMMIT END TRY BEGIN CATCH ROLLBACK ... END CATCH` |
| **"Cada tabla ya posee un trigger INSTEAD OF que no puede modificarse"** | SQL Server no admite dos triggers `INSTEAD OF` sobre la misma tabla y evento. | El trigger **obligatoriamente debe ser `AFTER`** (`AFTER INSERT, UPDATE, DELETE`). |

---

## 🛠️ PARTE I: Los 4 Moldes Maestros de T-SQL

### Molde 1: Trigger de Validación / Restricción de Negocio
> **Cuándo usarlo:** Simular restricciones `UNIQUE`, impedir borrado con stock, límites de compra, validación de integridad referencial sin Foreign Key, etc.

```sql
CREATE TRIGGER TR_ValidarRegla
ON TablaVigilada                -- Dónde se produce el evento (ej: Producto, Item_Factura, Factura)
AFTER INSERT, UPDATE, DELETE    -- Elegir según la operación vigilada
AS
BEGIN
    SET NOCOUNT ON;

    -- Validación 1: Comparar contra filas de la base de datos
    IF EXISTS (
        SELECT 1
        FROM TablaFisica t
        JOIN inserted i ON t.clave = i.clave
        WHERE /* Condición que rompe la regla */ 1 = 1
    )
    -- Validación 2: Chequear duplicados internos dentro del lote insertado
    OR EXISTS (
        SELECT 1
        FROM inserted
        GROUP BY columna_que_debe_ser_unica
        HAVING COUNT(*) > 1
    )
    BEGIN
        RAISERROR('Operación cancelada: se violó una regla de negocio.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
END;
```

---

### Molde 2: Trigger de Consistencia / Actualización Directa
> **Cuándo usarlo:** Descuento automático de stock al vender, imputación de pagos, ajuste de saldos. Garantiza soporte completo para lotes sin perder filas repetidas.

```sql
CREATE TRIGGER TR_ItemFactura_DescontarStock
ON Item_Factura
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Agrupar las filas entrantes para evitar actualizar dos veces la misma fila física
    DECLARE @resumen_ventas TABLE (
        producto CHAR(8),
        total_vendido DECIMAL(12,2)
    );

    INSERT INTO @resumen_ventas (producto, total_vendido)
    SELECT 
        item_producto,
        SUM(item_cantidad)
    FROM inserted
    GROUP BY item_producto;

    -- 2. Impactar directamente sobre la tabla física con un JOIN
    UPDATE s
    SET s.stoc_cantidad = s.stoc_cantidad - r.total_vendido
    FROM STOCK s
    JOIN @resumen_ventas r ON s.stoc_producto = r.producto
    WHERE s.stoc_deposito = '00';
END;
```

---

### Molde 3: Trigger de Tabla Acumulada / Histórica en Tiempo Real (MERGE)
> **Cuándo usarlo:** Mantener una tabla resumen (`ProductosAcumulados`, estadísticas mensuales) actualizada ante cualquier alta, baja o modificación de ventas.

```sql
CREATE TRIGGER TR_SincronizarAcumulados
ON Item_Factura
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Capturar todas las claves que sufrieron cambios (altas, modificaciones o bajas)
    DECLARE @afectados TABLE (
        id CHAR(8),
        periodo INT
    );

    INSERT INTO @afectados
    SELECT DISTINCT i.item_producto, YEAR(f.fact_fecha) * 100 + MONTH(f.fact_fecha)
    FROM inserted i
    JOIN Factura f ON i.item_tipo = f.fact_tipo AND i.item_sucursal = f.fact_sucursal AND i.item_numero = f.fact_numero
    UNION
    SELECT DISTINCT d.item_producto, YEAR(f.fact_fecha) * 100 + MONTH(f.fact_fecha)
    FROM deleted d
    JOIN Factura f ON d.item_tipo = f.fact_tipo AND d.item_sucursal = f.fact_sucursal AND d.item_numero = f.fact_numero;

    -- 2. Recalcular y sincronizar con MERGE
    MERGE INTO TablaAcumulada AS Destino
    USING (
        SELECT 
            af.id,
            af.periodo,
            SUM(ifa.item_cantidad)                   AS total_cant,
            MAX(ifa.item_precio)                     AS precio_max,
            MIN(ifa.item_precio)                     AS precio_min,
            SUM(ifa.item_cantidad * ifa.item_precio) AS total_monto
        FROM (SELECT DISTINCT id, periodo FROM @afectados) af
        JOIN Factura f ON (YEAR(f.fact_fecha) * 100 + MONTH(f.fact_fecha)) = af.periodo
        JOIN Item_Factura ifa ON ifa.item_tipo = f.fact_tipo 
                             AND ifa.item_sucursal = f.fact_sucursal 
                             AND ifa.item_numero = f.fact_numero
                             AND ifa.item_producto = af.id
        GROUP BY af.id, af.periodo
    ) AS Origen
    ON (Destino.id = Origen.id AND Destino.periodo = Origen.periodo)
    
    WHEN MATCHED THEN
        UPDATE SET 
            Destino.total_cant  = Origen.total_cant,
            Destino.precio_max  = Origen.precio_max,
            Destino.precio_min  = Origen.precio_min,
            Destino.total_monto = Origen.total_monto

    WHEN NOT MATCHED BY TARGET THEN
        INSERT (id, periodo, total_cant, precio_max, precio_min, total_monto)
        VALUES (Origen.id, Origen.periodo, Origen.total_cant, Origen.precio_max, Origen.precio_min, Origen.total_monto);

    -- 3. Limpieza: Si se borraron todas las ventas de ese período para ese producto, eliminar el registro
    DELETE ta
    FROM TablaAcumulada ta
    JOIN (SELECT DISTINCT id, periodo FROM @afectados) af 
        ON ta.id = af.id AND ta.periodo = af.periodo
    WHERE NOT EXISTS (
        SELECT 1 
        FROM Factura f
        JOIN Item_Factura ifa ON ifa.item_tipo = f.fact_tipo 
                             AND ifa.item_sucursal = f.fact_sucursal 
                             AND ifa.item_numero = f.fact_numero
        WHERE ifa.item_producto = af.id
          AND (YEAR(f.fact_fecha) * 100 + MONTH(f.fact_fecha)) = af.periodo
    );
END;
```

---

### Molde 4: Stored Procedure con Transacciones Atómicas
> **Cuándo usarlo:** Procesos donde intervienen dos o más escrituras que deben confirmarse juntas o revertirse en caso de falla (`BEGIN TRAN / COMMIT / ROLLBACK`).

```sql
CREATE PROCEDURE dbo.sp_OperacionTransaccional
    @param_producto CHAR(8),
    @param_deposito CHAR(2),
    @param_cantidad DECIMAL(12,2)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Modificación en la primera tabla
        INSERT INTO MovimientoStock (mov_producto, mov_deposito, mov_cantidad, mov_fecha)
        VALUES (@param_producto, @param_deposito, @param_cantidad, GETDATE());

        -- 2. Modificación en la segunda tabla
        UPDATE STOCK
        SET stoc_cantidad = stoc_cantidad + @param_cantidad
        WHERE stoc_producto = @param_producto 
          AND stoc_deposito = @param_deposito;

        -- Si todo fue exitoso, se confirman los cambios
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Si cualquier sentencia arrojó error, se revierten todos los cambios
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH;
END;
```

---

## 📊 PARTE II: Los Patrones Clave de SQL DML

### Patrón 1: Subconsulta Correlacionada Escalar (El Período o Ítem "Top")
*Reemplaza el uso de CTEs o subqueries en el `FROM` para obtener el elemento dominante de cada fila.*

```sql
(
    SELECT TOP 1 (YEAR(f2.fact_fecha) * 100 + MONTH(f2.fact_fecha))
    FROM Factura f2
    JOIN Item_Factura if2 ON f2.fact_tipo = if2.item_tipo 
                         AND f2.fact_sucursal = if2.item_sucursal 
                         AND f2.fact_numero = if2.item_numero
    WHERE f2.fact_cliente = c.clie_codigo
    GROUP BY YEAR(f2.fact_fecha) * 100 + MONTH(f2.fact_fecha)
    ORDER BY SUM(if2.item_cantidad) DESC
) AS periodo_mayor_compras
```

### Patrón 2: Pares Únicos con Self-Join sin Duplicados Espejo (`p1 > p2`)
*Empareja dos productos o entidades vendidas juntas en una misma factura evitando que aparezca $A-B$ y luego $B-A$.*

```sql
SELECT 
    p1.prod_codigo AS prod1,
    p2.prod_codigo AS prod2,
    COUNT(DISTINCT i1.item_tipo + i1.item_sucursal + i1.item_numero) AS veces_juntos
FROM Item_Factura i1
JOIN Item_Factura i2 
    ON i1.item_tipo = i2.item_tipo 
   AND i1.item_sucursal = i2.item_sucursal 
   AND i1.item_numero = i2.item_numero
   AND i1.item_producto > i2.item_producto -- Clave para unicidad estricta del par
JOIN Producto p1 ON i1.item_producto = p1.prod_codigo
JOIN Producto p2 ON i2.item_producto = p2.prod_codigo
GROUP BY p1.prod_codigo, p2.prod_codigo
HAVING COUNT(DISTINCT i1.item_tipo + i1.item_sucursal + i1.item_numero) > 50;
```

### Patrón 3: Numeración Correlativa y Formateo Decimal
```sql
-- Numerador correlativo desde 1 ordenado alfabéticamente
ROW_NUMBER() OVER (ORDER BY p.prod_detalle ASC) AS nro_fila,

-- Porcentaje relativo formateado a 2 decimales sin nulos
ISNULL(
    CAST((SUM(ifa.item_cantidad) * 100.0) / (
        SELECT SUM(item_cantidad) 
        FROM Item_Factura if_tot
        JOIN Factura f_tot ON if_tot.item_tipo = f_tot.fact_tipo 
                          AND if_tot.item_sucursal = f_tot.fact_sucursal 
                          AND if_tot.item_numero = f_tot.fact_numero
        WHERE YEAR(f_tot.fact_fecha) > 2020
    ) AS DECIMAL(10,2)), 
    0.00
) AS porcentaje_total
```

### Patrón 4: Verificación de Años Consecutivos Dinámicos
```sql
WHERE YEAR(f.fact_fecha) > 2020
  AND EXISTS (
      -- Año base
      SELECT 1 
      FROM Item_Factura if1
      JOIN Factura f1 ON if1.item_tipo = f1.fact_tipo AND if1.item_sucursal = f1.fact_sucursal AND if1.item_numero = f1.fact_numero
      WHERE if1.item_producto = p.prod_codigo 
        AND YEAR(f1.fact_fecha) > 2020
        -- Año consecutivo + 1
        AND EXISTS (
            SELECT 1 
            FROM Item_Factura if2
            JOIN Factura f2 ON if2.item_tipo = f2.fact_tipo AND if2.item_sucursal = f2.fact_sucursal AND if2.item_numero = f2.fact_numero
            WHERE if2.item_producto = p.prod_codigo 
              AND YEAR(f2.fact_fecha) = YEAR(f1.fact_fecha) + 1
        )
        -- Año consecutivo + 2
        AND EXISTS (
            SELECT 1 
            FROM Item_Factura if3
            JOIN Factura f3 ON if3.item_tipo = f3.fact_tipo AND if3.item_sucursal = f3.fact_sucursal AND if3.item_numero = f3.fact_numero
            WHERE if3.item_producto = p.prod_codigo 
              AND YEAR(f3.fact_fecha) = YEAR(f1.fact_fecha) + 2
        )
  )
```

---

## 📝 Glosario Rápido de Palabras Clave

* **`CONSTRAINT`**: Regla declarativa en la definición de la tabla (`PRIMARY KEY`, `FOREIGN KEY`, `UNIQUE`, `CHECK`) para forzar consistencia de datos a nivel de motor.
* **`MERGE INTO ... USING ...`**: Instrucción atómica que combina `INSERT`, `UPDATE` y `DELETE` evaluando si una fila existe o no en una sola pasada.
* **`TARGET`**: La tabla destino que va a ser modificada o sincronizada por el `MERGE`.
* **`WHEN MATCHED`**: Bloque que se ejecuta cuando la clave ya existe en el `TARGET` (típicamente ejecuta un `UPDATE`).
* **`WHEN NOT MATCHED BY TARGET`**: Bloque que se ejecuta cuando el registro es nuevo y todavía no existe en el `TARGET` (ejecuta un `INSERT`).
* **`inserted` / `deleted`**: Tablas temporales virtuales en memoria que contienen las filas recién insertadas o modificadas/eliminadas durante la ejecución de un trigger.