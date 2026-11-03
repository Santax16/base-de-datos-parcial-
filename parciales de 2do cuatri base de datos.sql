-- ====================================================================================
-- EXAMEN 1: PARCIAL PRÁCTICO (20-09-2025) - SQL DML
-- ====================================================================================
/*
ENUNCIADO:
Crear una consulta SQL que identifique los 10 primeros productos que, durante
tres años consecutivos, hayan registrado en cada año un incremento mínimo del
20 % en sus cantidades vendidas respecto al año anterior.
De los productos seleccionados, mostrar únicamente aquellos que actualmente
dispongan de stock en al menos el 75 % de los depósitos.

Los datos a mostrar por cada producto que cumpla con la consigna son:
1. Nombre del producto
2. Fecha de última compra del producto
3. Cantidad de clientes que lo compraron en el 2025.

Nota: No está permitido utilizar subconsultas en la cláusula FROM (select ... from
(select) ), ni recurrir a expresiones de tabla comunes (CTE, es decir, WITH ...).
*/

SELECT TOP 10
    -- 1. Nombre del producto
    p.prod_detalle,

    -- 2. Fecha de última compra del producto (Subconsulta correlacionada escalar)
    ISNULL(CONVERT(VARCHAR(10), (
        SELECT MAX(f_ult.fact_fecha)
        FROM Factura f_ult
        JOIN Item_Factura if_ult 
            ON f_ult.fact_tipo = if_ult.item_tipo 
           AND f_ult.fact_sucursal = if_ult.item_sucursal 
           AND f_ult.fact_numero = if_ult.item_numero
        WHERE if_ult.item_producto = p.prod_codigo
    ), 120), 'SIN VENTAS') AS fecha_ultima_compra,

    -- 3. Cantidad de clientes que lo compraron en el 2025
    ISNULL((
        SELECT COUNT(DISTINCT f_25.fact_cliente)
        FROM Factura f_25
        JOIN Item_Factura if_25 
            ON f_25.fact_tipo = if_25.item_tipo 
           AND f_25.fact_sucursal = if_25.item_sucursal 
           AND f_25.fact_numero = if_25.item_numero
        WHERE if_25.item_producto = p.prod_codigo
          AND YEAR(f_25.fact_fecha) = 2025
    ), 0) AS cant_clientes_2025

FROM Producto p
WHERE 
    -- CONDICIÓN 1: Disponer de stock en al menos el 75% de los depósitos actuales
    (
        SELECT COUNT(*) 
        FROM STOCK s 
        WHERE s.stoc_producto = p.prod_codigo 
          AND s.stoc_cantidad > 0
    ) >= (
        SELECT COUNT(*) * 0.75 
        FROM DEPOSITO
    )

    -- CONDICIÓN 2: Tres años consecutivos con incremento mínimo del 20% anual
    -- Existe un año base Y tal que:
    -- Ventas(Y+1) >= Ventas(Y) * 1.20  Y  Ventas(Y+2) >= Ventas(Y+1) * 1.20
    AND EXISTS (
        SELECT 1
        FROM Factura f_base
        JOIN Item_Factura if_base 
            ON f_base.fact_tipo = if_base.item_tipo 
           AND f_base.fact_sucursal = if_base.item_sucursal 
           AND f_base.fact_numero = if_base.item_numero
        WHERE if_base.item_producto = p.prod_codigo
          AND EXISTS (
              -- Año 2 (consecutivo 1): Incremento >= 20% respecto a año base
              SELECT 1
              FROM Factura f_sig1
              JOIN Item_Factura if_sig1 
                  ON f_sig1.fact_tipo = if_sig1.item_tipo 
                 AND f_sig1.fact_sucursal = if_sig1.item_sucursal 
                 AND f_sig1.fact_numero = if_sig1.item_numero
              WHERE if_sig1.item_producto = p.prod_codigo
                AND YEAR(f_sig1.fact_fecha) = YEAR(f_base.fact_fecha) + 1
              GROUP BY YEAR(f_sig1.fact_fecha)
              HAVING SUM(if_sig1.item_cantidad) >= (
                  -- Subconsulta total año base
                  SELECT SUM(if_prev1.item_cantidad) * 1.20
                  FROM Item_Factura if_prev1
                  JOIN Factura f_prev1 
                      ON if_prev1.item_tipo = f_prev1.fact_tipo 
                     AND if_prev1.item_sucursal = f_prev1.fact_sucursal 
                     AND if_prev1.item_numero = f_prev1.fact_numero
                  WHERE if_prev1.item_producto = p.prod_codigo
                    AND YEAR(f_prev1.fact_fecha) = YEAR(f_base.fact_fecha)
              )
          )
          AND EXISTS (
              -- Año 3 (consecutivo 2): Incremento >= 20% respecto a año 2
              SELECT 1
              FROM Factura f_sig2
              JOIN Item_Factura if_sig2 
                  ON f_sig2.fact_tipo = if_sig2.item_tipo 
                 AND f_sig2.fact_sucursal = if_sig2.item_sucursal 
                 AND f_sig2.fact_numero = if_sig2.item_numero
              WHERE if_sig2.item_producto = p.prod_codigo
                AND YEAR(f_sig2.fact_fecha) = YEAR(f_base.fact_fecha) + 2
              GROUP BY YEAR(f_sig2.fact_fecha)
              HAVING SUM(if_sig2.item_cantidad) >= (
                  -- Subconsulta total año 2
                  SELECT SUM(if_prev2.item_cantidad) * 1.20
                  FROM Item_Factura if_prev2
                  JOIN Factura f_prev2 
                      ON if_prev2.item_tipo = f_prev2.fact_tipo 
                     AND if_prev2.item_sucursal = f_prev2.fact_sucursal 
                     AND if_prev2.item_numero = f_prev2.fact_numero
                  WHERE if_prev2.item_producto = p.prod_codigo
                    AND YEAR(f_prev2.fact_fecha) = YEAR(f_base.fact_fecha) + 1
              )
          )
    )
ORDER BY p.prod_detalle ASC;
GO


-- ====================================================================================
-- EXAMEN 2: 2do PARCIAL PRÁCTICO (01-11-2025) - TRANSACT-SQL
-- ====================================================================================
/*
ENUNCIADO:
Se requiere mantener precalculada toda la información relacionada con las ventas, de modo
que pueda consultarse de forma rápida y eficiente.
La información a mantener debe incluir, para cada combinación de mes, año y producto:
- Cantidad total vendida
- Precio máximo de venta
- Precio mínimo de venta
- Cliente que más compró (por cantidad)

Se deberán implementar los objetos necesarios en SQL (tablas, vistas, índices,
procedimientos, etc.) para garantizar que esta información:
1. Esté siempre disponible y actualizada, reflejando los datos de ventas.
2. Permita un acceso optimizado a las consultas filtradas por mes y año.
*/

-- PARTE A: Creación de la Tabla Precalculada
IF OBJECT_ID('dbo.Resumen_Ventas_Mensual', 'U') IS NOT NULL
    DROP TABLE dbo.Resumen_Ventas_Mensual;
GO

CREATE TABLE dbo.Resumen_Ventas_Mensual (
    res_anio INT NOT NULL,
    res_mes INT NOT NULL,
    res_producto CHAR(8) NOT NULL,
    res_cantidad_total DECIMAL(12,2) NOT NULL DEFAULT 0,
    res_precio_maximo DECIMAL(12,2) NOT NULL DEFAULT 0,
    res_precio_minimo DECIMAL(12,2) NOT NULL DEFAULT 0,
    res_cliente_top CHAR(6) NULL,
    CONSTRAINT PK_Resumen_Ventas PRIMARY KEY (res_anio, res_mes, res_producto)
);
GO

-- PARTE B: Índice no agrupado para cumplir el Punto 2 (acceso optimizado por mes y año)
CREATE NONCLUSTERED INDEX IX_Resumen_Ventas_FiltroFecha
ON dbo.Resumen_Ventas_Mensual (res_anio, res_mes)
INCLUDE (res_producto, res_cantidad_total, res_cliente_top);
GO

-- PARTE C: Trigger en Item_Factura para mantener la información siempre actualizada
CREATE OR ALTER TRIGGER dbo.TR_ItemFactura_PrecalculoVentas
ON dbo.Item_Factura
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Capturar todas las combinaciones afectadas de (año, mes, producto)
    DECLARE @afectados TABLE (
        anio INT NOT NULL,
        mes INT NOT NULL,
        producto CHAR(8) NOT NULL
    );

    INSERT INTO @afectados (anio, mes, producto)
    SELECT DISTINCT 
        YEAR(f.fact_fecha),
        MONTH(f.fact_fecha),
        i.item_producto
    FROM inserted i
    JOIN Factura f 
        ON i.item_tipo = f.fact_tipo 
       AND i.item_sucursal = f.fact_sucursal 
       AND i.item_numero = f.fact_numero
    UNION
    SELECT DISTINCT 
        YEAR(f.fact_fecha),
        MONTH(f.fact_fecha),
        d.item_producto
    FROM deleted d
    JOIN Factura f 
        ON d.item_tipo = f.fact_tipo 
       AND d.item_sucursal = f.fact_sucursal 
       AND d.item_numero = f.fact_numero;

    -- 2. Recalcular las métricas requeridas para el lote afectado
    -- y sincronizar la tabla con MERGE
    MERGE INTO dbo.Resumen_Ventas_Mensual AS Destino
    USING (
        SELECT 
            af.anio,
            af.mes,
            af.producto,
            SUM(ifa.item_cantidad) AS cant_total,
            MAX(ifa.item_precio)   AS p_max,
            MIN(ifa.item_precio)   AS p_min,
            -- Cliente que más compró por cantidad en ese año, mes y producto
            (
                SELECT TOP 1 f_top.fact_cliente
                FROM Factura f_top
                JOIN Item_Factura if_top 
                    ON f_top.fact_tipo = if_top.item_tipo 
                   AND f_top.fact_sucursal = if_top.item_sucursal 
                   AND f_top.fact_numero = if_top.item_numero
                WHERE if_top.item_producto = af.producto
                  AND YEAR(f_top.fact_fecha) = af.anio
                  AND MONTH(f_top.fact_fecha) = af.mes
                GROUP BY f_top.fact_cliente
                ORDER BY SUM(if_top.item_cantidad) DESC
            ) AS cliente_top
        FROM @afectados af
        JOIN Factura f 
            ON YEAR(f.fact_fecha) = af.anio 
           AND MONTH(f.fact_fecha) = af.mes
        JOIN Item_Factura ifa 
            ON ifa.item_tipo = f.fact_tipo 
           AND ifa.item_sucursal = f.fact_sucursal 
           AND ifa.item_numero = f.fact_numero
           AND ifa.item_producto = af.producto
        GROUP BY af.anio, af.mes, af.producto
    ) AS Origen
    ON (
        Destino.res_anio = Origen.anio 
        AND Destino.res_mes = Origen.mes 
        AND Destino.res_producto = Origen.producto
    )

    -- Si la fila ya existe para esa combinación, actualizamos
    WHEN MATCHED THEN
        UPDATE SET 
            Destino.res_cantidad_total = Origen.cant_total,
            Destino.res_precio_maximo  = Origen.p_max,
            Destino.res_precio_minimo  = Origen.p_min,
            Destino.res_cliente_top    = Origen.cliente_top

    -- Si es la primera vez que se vende en ese mes y año, insertamos
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (res_anio, res_mes, res_producto, res_cantidad_total, res_precio_maximo, res_precio_minimo, res_cliente_top)
        VALUES (Origen.anio, Origen.mes, Origen.producto, Origen.cant_total, Origen.p_max, Origen.p_min, Origen.cliente_top);

    -- 3. Limpieza: Si se borraron todas las ventas de ese producto en ese mes/año, borrar la fila
    DELETE r
    FROM dbo.Resumen_Ventas_Mensual r
    JOIN @afectados af 
        ON r.res_anio = af.anio 
       AND r.res_mes = af.mes 
       AND r.res_producto = af.producto
    WHERE NOT EXISTS (
        SELECT 1
        FROM Factura f
        JOIN Item_Factura ifa 
            ON ifa.item_tipo = f.fact_tipo 
           AND ifa.item_sucursal = f.fact_sucursal 
           AND ifa.item_numero = f.fact_numero
        WHERE ifa.item_producto = af.producto
          AND YEAR(f.fact_fecha) = af.anio
          AND MONTH(f.fact_fecha) = af.mes
    );
END;
GO