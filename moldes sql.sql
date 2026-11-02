El Período AAAAMM o el "Más Vendido/Facturado" (Subconsulta Correlacionada Escalar)
Se usa cuando prohíben subcon(
    SELECT TOP 1 (YEAR(f2.fact_fecha) * 100 + MONTH(f2.fact_fecha))
    FROM Factura f2
    JOIN Item_Factura if2 ON f2.fact_tipo = if2.item_tipo 
                         AND f2.fact_sucursal = if2.item_sucursal 
                         AND f2.fact_numero = if2.item_numero
    WHERE f2.fact_cliente = c.clie_codigo -- Correlación con la fila principal
    GROUP BY YEAR(f2.fact_fecha) * 100 + MONTH(f2.fact_fecha)
    ORDER BY SUM(if2.item_cantidad) DESC
) AS periodo_mayor_comprasultas en el FROM o CTEs y piden traer el año/mes o el código de mayor valor.

 Pares Únicos sin Duplicados Espejo (p1 > p2)
Se usa cuando piden pares de productos o familias vendidos juntos en la misma factura.

SELECT 
    p1.prod_codigo AS prod1,
    p2.prod_codigo AS prod2,
    COUNT(DISTINCT i1.item_tipo + i1.item_sucursal + i1.item_numero) AS veces_juntos
FROM Item_Factura i1
JOIN Item_Factura i2 
    ON i1.item_tipo = i2.item_tipo 
   AND i1.item_sucursal = i2.item_sucursal 
   AND i1.item_numero = i2.item_numero
   AND i1.item_producto > i2.item_producto -- Evita el espejo (A-B y B-A) y emparejarse consigo mismo
JOIN Producto p1 ON i1.item_producto = p1.prod_codigo
JOIN Producto p2 ON i2.item_producto = p2.prod_codigo
GROUP BY p1.prod_codigo, p2.prod_codigo
HAVING COUNT(DISTINCT i1.item_tipo + i1.item_sucursal + i1.item_numero) > 50;

 Numerador Correlativo
(ROW_NUMBER)Obligatorio cuando el enunciado exige "número de fila correlativo empezando en 1".   SQLROW_NUMBER() OVER (ORDER BY p.prod_detalle ASC) AS nro_fila

 Porcentaje Respecto al Total Global
Calcula el peso relativo dividiendo la suma local por un SELECT SUM(...)

(SUM(ifa.item_cantidad) * 100.0) / (
    SELECT SUM(item_cantidad) 
    FROM Item_Factura if_tot
    JOIN Factura f_tot ON if_tot.item_tipo = f_tot.fact_tipo 
                      AND if_tot.item_sucursal = f_tot.fact_sucursal 
                      AND if_tot.item_numero = f_tot.fact_numero
    WHERE YEAR(f_tot.fact_fecha) = 2011 -- Mismo filtro temporal global
) AS porcentaje_total