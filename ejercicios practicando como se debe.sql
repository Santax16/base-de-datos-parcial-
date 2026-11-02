// mostrar el codigo , razon social de todos los clientes cuyo limite de credito sea mayor
//o igual a 1000 ordenado por codigo de cliente

SELECT
     clie_codigo,
     clie_razon_social
FROM Cliente
WHERE clie_limite_credito >= 1000
ORDER BY clie_codigo ASC; 

//


// 2

SELECT 
      prod_codigo,
      prod_detalle
FROM Producto p
JOIN Item_Factura i
 ON p.prod_codigo = i.item_producto
JOIN Factura f
 ON i.item_tipo = f.fact_tipo
 AND i.item_sucursal = f.fact_sucursal
 AND i.item_numero = f.fact_numero
 WHERE YEAR (f.fact_fecha) = 2012
 GROUP BY 
    p.prod_codigo,
    p.prod_detalle
ORDER BY SUM(ifa.item_cantidad)DESC;

// 3

 SELECT 
       prod_codigo,
       prod_detalle,
       SUM(stoc_cantidad) AS total_stock
 FROM Producto p
 Join STOCK s
  ON p.prod_codigo = s.stoc_producto
  GROUP BY
   prod_codigo,
   prod_detalle
  ORDER BY p.prod_detalle ASC;

/*
4. Realizar una consulta que muestre para todos los artículos código, detalle y cantidad de
artículos que lo componen. Mostrar solo aquellos artículos para los cuales el stock
promedio por depósito sea mayor a 100.
*/

SELECT 
     prod_codigo,
     prod_detalle, 
      ( 
         SELECT ISNULL(COUNT(c.comp_componente), 0)// Una subconsulta es simplemente una pregunta auxiliar que resuelve una incógnita independiente.
         FROM Composicion c
         WHERE c.comp_producto = p.prod_codigo
         ) AS cantidad_componentes
     FROM Producto p
     JOIN STOCK s
        ON p.prod_codigo = s.stoc_producto
     GROUP BY 
        prod_codigo,
        prod_detalle
    HAVING AVG(s.stoc_cantidad) > 100


// 5 

SELECT 
   p.prod_codigo,
   p.prod_detalle,
      (
         SELECT ISNULL(SUM(ifa.item_cantidad),0)
         FROM Item_Factura ifa
         JOIN Factura f
           ON ifa.item_tipo = f.fact_tipo
           AND ifa.item_sucursal = f.fact_sucursal
           AND ifa.item_numero = f.fact_numero
        WHERE ifa.item_producto = p.prod_codigo 
           AND YEAR(f.fact_fecha) = 2012
      ) AS egresos_2012
    FROM Producto p
    WHERE
       (
          SELECT ISNULL(SUM(ifa.item_cantidad), 0)
        FROM Item_Factura ifa
        JOIN Factura f 
            ON  ifa.item_tipo = f.fact_tipo
            AND ifa.item_sucursal = f.fact_sucursal
            AND ifa.item_numero = f.fact_numero
        WHERE ifa.item_producto = p.prod_codigo
          AND YEAR(f.fact_fecha) = 2012
      )
      > 
    (
        SELECT ISNULL(SUM(ifa.item_cantidad), 0)
        FROM Item_Factura ifa
        JOIN Factura f 
            ON  ifa.item_tipo = f.fact_tipo
            AND ifa.item_sucursal = f.fact_sucursal
            AND ifa.item_numero = f.fact_numero
        WHERE ifa.item_producto = p.prod_codigo
          AND YEAR(f.fact_fecha) = 2011
    );

// 6 

SELECT 
  rubr_id,
  rubr_detalle
  COUNT(DISTINCT p.prod_codigo) AS cantidad_productos
  SUM(s.stoc_cantidad) AS total_stock_rubro
  FROM Rubro r
  JOIN Producto p
  ON r.rubr_id = p.prod_rubro
  JOIN STOCK s
  ON p.prod_codigo = s.stoc_producto
  WHERE s.stoc_cantidad >
  (SELECT stoc_cantidad
  FROM STOCK s
  WHERE s.stoc_producto = '00000000' AND s.stoc_deposito = '00')
  GROUP BY 
  r.rubr_id,
  r.rubr_detalle;

  // 7

  SELECT 
   prod_codigo,
   prod_detalle,
   MAX(ifa.item_precio),
   MIN(ifa.item_precio),
   (MAX(ifa.item_precio) - MIN(ifa.item_precio)) * 100.0 / MIN(ifa.item_precio)
   FROM Producto p
   JOIN Item_Factura ifa
      ON p.prod_codigo = ifa.item_producto
   WHERE(
 SELECT SUM(s.stoc_cantidad)
 FROM STOCK s
 WHERE s.stoc_producto = p.prod_codigo) > 0
 GROUP BY prod_codigo,
 prod_detalle




 // 8 Vamos con el Ejercicio 8. Este ejercicio introduce un clásico de parcial: la condición de "en todos los..." (que en teoría relacional se conoce como el operador de División).

 SELECT 
 p.prod_detalle,
 MAX(stoc_cantidad) AS stock_maximo_deposito,
 FROM Producto p
 JOIN STOCK s
   ON p.prod_codigo = s.stoc_producto
 WHERE s.stoc_cantidad > 0
 GROUP BY p.prod_codigo,
 p.prod_detalle
  HAVING COUNT(DISTINCT s.stoc_deposito) = (SELECT COUNT(*) FROM DEPOSITO)



// 9 Vamos a encarar el Ejercicio 9, que introduce otra técnica clásica de bases de datos: unir una tabla consigo misma (Self-Join o Auto-unión).
solucion sin left join

empl_codigo,
empl_jefe,
empl_nombre,
((SELECT COUNT(*) FROM DEPOSITO d WHERE d.depo_encargado = e.empl_codigo)
 +
 (SELECT COUNT(*) FROM DEPOSITO d WHERE d.depo_encargado = j.empl_codigo)) AS depositos_ambos
 FROM Empleado e
JOIN Empleado j
 ON e.empl_jefe = j.empl_codigo;

 solucion con LEFT JOIN y group by

 SELECT 
 j.empl_codigo AS codigo_jefe,
    e.empl_codigo AS codigo_empleado,
    e.empl_nombre AS nombre_empleado,
    COUNT (DISTINCT de.depo_codigo) + COUNT (DISTINCT dj.depo_codigo) AS cantidad_depositos_ambos
    FROM Empleado e
    JOIN Empleado j
    ON e.empl_jefe = j.empl_codigo
    LEFT JOIN DEPOSITO de
      ON e.empl_codigo = de.depo_encargado
    LEFT JOIN DEPOSITO dj
      ON j.empl_codigo = dj.depo_encargado
     GROUP BY 
        j.empl_codigo,
        e.empl_codigo,
        e.empl_nombre;


        // 10 El Ejercicio 10 presenta varios desafíos: combina dos rankings opuestos con UNION, maneja desempates con TOP WITH TIES y calcula el mejor cliente de cada artículo mediante una subconsulta correlacionada.

        SELECT TOP 10
         p.prod_codigo,
         p.prod_detalle,
         SUM(ifa.item_cantidad) AS total_vendido
         ( 
         SELECT TOP 1 f.fact_cliente
         FROM Factura f
         JOIN Item_factura ifa2
            ON  f.fact_tipo = ifa2.item_tipo
            AND f.fact_sucursal = ifa2.item_sucursal
            AND f.fact_numero = ifa2.item_numero
        WHERE ifa2.item_producto = p.prod_codigo
        GROUP BY f.fact_cliente
        ORDER BY SUM (ifa2.item_cantidad) DESC) AS cliente_mas_comprador
        FROM Producto p
        JOIN Item_Factura ifa
          ON p.prod_codigo = ifa.item_producto
          GROUP BY 
          p.prod_codigo,
          p.prod_detalle
          ORDER BY SUM(ifa.item_cantidad) DESC
          ) AS Mas_Vendidos

          UNION ALL

          SELECT * 
          FROM (
           -- 10 productos menos vendidos de la historia
           SELECT TOP 10
            p.prod_codigo,
            p.prod_detalle,
            SUM(ifa.item_cantidad) AS total_vendido,
            (
              SELECT TOP 1 f.fact_cliente
              FROM Factura f
              JOIN Item_factura ifa2
                 ON  f.fact_tipo = ifa2.item_tipo
                 AND f.fact_sucursal = ifa2.item_sucursal
                 AND f.fact_numero = ifa2.item_numero
              WHERE ifa2.item_producto = p.prod_codigo
              GROUP BY f.fact_cliente
              ORDER BY SUM(ifa.item_cantidad) DESC) As cliente_mas_comprador
              FROM Producto p
              JOIN Item_Factura ifa
              ON p.prod_codigo = ifa.item_producto 
              GROUP BY 
              p.prod_codigo,
              p.prod_detalle,
              ORDER BY SUM(ifa.item_cantidad) ASC
              ) AS MenosVendidos;

 // 11


 SELECT 
    fam.fami_detalle,
    COUNT(DISTINCT p.prod_codigo) AS cant_productos_distintos,
    SUM(ifa.item_cantidad * ifa.item_precio) AS monto_sin_impuestos
FROM Familia fam
JOIN Producto p 
    ON fam.fami_id = p.prod_familia
JOIN Item_Factura ifa 
    ON p.prod_codigo = ifa.item_producto
JOIN Factura f 
    ON  ifa.item_tipo = f.fact_tipo
    AND ifa.item_sucursal = f.fact_sucursal
    AND ifa.item_numero = f.fact_numero
WHERE YEAR(f.fact_fecha) = 2012
GROUP BY 
    fam.fami_id, 
    fam.fami_detalle
HAVING SUM(ifa.item_cantidad * ifa.item_precio) > 20000
ORDER BY COUNT(DISTINCT p.prod_codigo) DESC;

-- 12

SELECT 
 prod_detalle
 COUNT(DISTINCT f.fact_cliente) AS clie_distintos,
 SUM(ifa.item_cantidad * ifa.item_precio) AS importe_total_vendido,
 (
 SELECT COUNT (DISTINCT s.stoc_deposito)
 FROM STOCK s
 WHERE s.stoc_producto = p.prod_codigo
 AND s.stoc_cantidad > 0
 ) AS cant_depositos_con_stock
 FROM Producto p
JOIN Item_Factura ifa 
    ON p.prod_codigo = ifa.item_producto
JOIN Factura f 
    ON  ifa.item_tipo = f.fact_tipo
    AND ifa.item_sucursal = f.fact_sucursal
    AND ifa.item_numero = f.fact_numero
GROUP BY 
    p.prod_codigo, 
    p.prod_detalle
 ORDER BY SUM(ifa.item_cantidad * ifa.item_precio) DESC;

 -- 13
 SELECT
 p.prod_detalle,
 p.prod_precio,
 SUM(p_hijo.prod_precio * c.comp_cantidad)
 FROM Producto p
 Join Composicion c
 ON p.prod_codigo = c.comp_producto
 JOIN Producto p_hijo
 ON c.comp_componente = p_hijo.prod_codigo

 Group by
 p.prod_codigo,
 p.prod_detalle,
 p.prod_precio
 Having COUNT (c.comp_componente) > 2
 ORDER BY COUNT(c.comp_componente) DESC;

 -- 14

 SELECT 
 clie.codigo,

 -- 1 cant veces q compro(contar facturas)
 ISNULL((
    SELECT COUNT(*)
    FROM Factura f
    WHERE f.fact_cliente = c.clie_codigo
      AND YEAR(f.fact_fecha) = (SELECT MAX(YEAR(f.fact_fecha)) FROM Factura)),0) AS veces_compro,
-- 2 promedio de compra
 ISNULL((
   SELECT AVG(f.fact_total)
   FROM Factura f
   WHERE f.fact_cliente = c.clie_codigo
      AND YEAR(f.fact_fecha) = (SELECT MAX(YEAR(f.fact_fecha)) FROM Factura)),0) AS promedio_por_compra
 ISNULL((
  SELECT COUNT(DISTINCT ifa.item_producto)
  FROM Factura f
  JOIN Item_factura ifa
     ON f.fact_tipo = ifa.item_tipo
     AND f.fact_sucursal = ifa.item_sucursal
     AND f.fact_numero = ifa.item_numero
    WHERE f.fact_cliente = c.clie_codigo
      AND YEAR(f.fact_fecha) = (SELECT MAX(YEAR(fact_fecha)) FROM Factura)),0) AS productos_diferentes
 ISNULL((
     SELECT MAX(f.fact_total)
     FROM Factura f
     WHERE f.fact_cliente = c.clie_codigo
     AND YEAR(f.fact_fecha) = (SELECT MAX(YEAR(fact_fecha)) FROM Factura)
), 0) AS mayor_compra
  FROM Cliente c
  ORDER BY veces_compro DESC;

  --16
  (
    SELECT ISNULL(SUM(ifa.item_cantidad),0)
    FROM Factura f
    JOIN Item_Factura ifa
     ON f.fact_tipo = ifa.item_tipo
     AND f.fact_sucursal = ifa.item_sucursal
     AND f.fact_numero  = ifa.item_numero
     WHERE f.fact_cliente = c.clie_codigo
     AND YEAR(f.fact_fecha) = 2012
     ) AS unidades_totales_2012
     (
      SELECT TOP 1 ifa2.item_producto
     FROM Item_Factura ifa2
     JOIN Factura f2
      ON f2.fact_tipo = ifa2.item_tipo
     AND f2.fact_sucursal = ifa2.item_sucursal
     AND f2.fact_numero  = ifa2.item_numero
     WHERE YEAR(f2.fact_fecha) = 2012
     ORDER BY SUM(ifa2.item_cantidad) DESC
     ) AS prod_mayor_venta
     FROM Cliente c
     WHERE
    (
        SELECT ISNULL(SUM(ifa.item_cantidad), 0)
        FROM Factura f
        JOIN Item_Factura ifa 
            ON  f.fact_tipo = ifa.item_tipo
            AND f.fact_sucursal = ifa.item_sucursal
            AND f.fact_numero = ifa.item_numero
        WHERE f.fact_cliente = c.clie_codigo
          AND YEAR(f.fact_fecha) = 2012
    )
    <
    (
     SELECT AVG(ifa3.item_cantidad) /3.0
     FROM Item_factura ifa3
     JOIN Factura f3
        ON f3.fact_tipo = ifa3.item_tipo
     AND f3.fact_sucursal = ifa3.item_sucursal
     AND f3.fact_numero  = ifa3.item_numero
     WHERE YEAR(f3.fact_fecha) = 2012
     AND ifa3.item_producto = (
     SELECT TOP 1 ifa2.item_producto
     FROM Item_Factura ifa2
     JOIN Factura f2
      ON f2.fact_tipo = ifa2.item_tipo
     AND f2.fact_sucursal = ifa2.item_sucursal
     AND f2.fact_numero  = ifa2.item_numero
     WHERE YEAR(f2.fact_fecha) = 2012
     ORDER BY SUM(ifa2.item_cantidad) DESC
     ))
     ORDER BY c.clie_domicilio ASC ;


     -- 15

     SELECT 
     p1.prod_codigo AS prod1,
     p1.prod_detalle AS detalle1,
     p2.prod_codigo  AS prod2,
     p2.prod_detalle AS detalle2,
     COUNT(*) AS veces
     FROM Item_factura ifa1
     JOIN Item_factura ifa2
          ON ifa1.item_tipo = ifa2.item_tipo
          AND ifa1.item_sucursal = ifa2.item_sucursal
          AND ifa1.item_numero = ifa2.item_numero
          AND ifa1.item_producto > ifa2.item_producto
    JOIN Producto p1
          ON ifa1.item_producto = p1.prod_codigo
    JOIN Producto p2
          ON ifa2.item_producto = p2.prod_codigo
     GROUP BY 
      p1.prod_codigo,
      p1.prod_detalle,
      p2.prod_codigo,
      p2.prod_detalle
    HAVING COUNT(*) > 500
    ORDER BY COUNT(*) DESC;

    --17

    SELECT 
      YEAR(f.fact_fecha) * 100 + MONTH(f.fact_fecha) AS PERIODO,
      p.prod_codigo AS PROD,
      p.prod_detalle AS DETALLE,
      SUM(ifa.item_cantidad) AS CANTIDAD_VENDIDA,
      IS NULL((
       SELECT SUM(ifa2.item_cantidad)
       FROM Item_Factura ifa2
       JOIN Factura f2
           ON  ifa2.item_tipo = f2.fact_tipo
            AND ifa2.item_sucursal = f2.fact_sucursal
            AND ifa2.item_numero = f2.fact_numero
        WHERE ifa2.item_producto = p.prod_codigo
           AND MONTH(f2.fact_fecha) = MONTH(f.fact_fecha)
          AND YEAR(f2.fact_fecha) = YEAR(f.fact_fecha) - 1
        ), 0) AS VENTAS_AÑO_ANT,
        COUNT(DISTINCT CONCAT(f.fact_tipo, f.fact_sucursal, f.fact_numero)) AS CANT_FACTURAS
    FROM Producto p
    JOIN Item_factura ifa
    ON p.prod_codigo = ifa.item_producto
    JOIN Factura f
    ON ifa.item_numero = f.fact_numero
    AND ifa.item_sucursal = f.fact_sucursal
    AND ifa.item_tipo = f.fact_tipo
    GROUP BY 
     YEAR(f.fact_fecha),
     MONTH(f.fact_fecha),
     p.prod_codigo,
     p.prod_detalle
     ORDER BY
     PERIODO ASC,
     PROD ASC;



     --20 
     SELECT TOP 3
      e.empl_codigo AS legajo,
      e.empl_nombre AS nombre,
      e.empl_apellido AS apellido,
      Year(e.empl_ingreso) AS anio_ingreso,

      -- puntaje 2011
      ISNULL(
        CASE
            WHEN(
            SELECT COUNT(*)
            FROM Factura f
            WHERE f.fact_vendedor = e.empl_codigo AND YEAR(f.fact_fecha) = 2011
            ) >= 50
            THEN (
            SELECT COUNT(*)
            FROM Factura f
            WHERE f.fact_vendedor = e.empl_codigo
            AND YEAR(f.fact_fecha) = 2011
            AND f.fact_total>100
            ) ELSE (
              SELECT COUNT(*) * 0.5
              FROM Factura f_sub
              JOIN Empleado sub ON f_sub.fact_vendedor = sub.empl_codigo
              WHERE sub.empl_jefe = e.empl_codigo
            )
            END,
            0) AS puntaje_2011,

       ISNULL(
         CASE 
             WHEN(
              SELECT COUNT(*)
              FROM Factura f
              WHERE f.fact_vendedor = e.empl_codigo AND YEAR (f.fact_fecha) = 2012
              ) >= 50
              THEN(
              SELECT COUNT(*)
              FROM Factura f
              WHERE f.fact_vendedor = e.empl_codigo
              AND YEAR(f.fact_fecha) = 2012
              AND f.fact_total > 100
              ) ELSE (
              SELECT COUNT(*) * 0.5
              FROM Factura f_sub
              JOIN Empleado sub ON f_sub.fact_vendedor = sub_empl_codigo
              WHERE sub.empl_jefe = e.empl_codigo

              )
              END,
              0) AS puntaje_2012,
              FROM Empleado e
              ORDER BY puntaje_2012 DESC;


              -- EJ PARCIAL
              SELECT
              ROW_NUMBER() OVER (ORDER BY p.prod_detalle ASC) AS nro_fila,
              p.prod_detalle
              SUM(ifa.item_cantidad) AS total_vendido
              
              ISNULL((
               SELECT TOP 1 f_top.fact_cliente
               FROM Factura f_top
               JOIN Item_factura if_top ON f_top.fact_tipo = if_top.item_tipo AND f_top.fact_sucursal = if_top.item_sucursal AND f_top.fact_numero = if_top.item_numero
               WHERE if_top.item_producto = p.prod_codigo
               AND YEAR (f_top.fact_fecha) > 2020
               GROUP BY f_top.fact_cliente
               ORDER BY SUM(if_top.item_cantidad) DESC
               ), 'SIN CLIENTE') AS cliente_mayor_comprador,

               CAST(( SUM(ifa.item_cantidad) * 100)/ (
               SELECT SUM(item_cantidad)
               FROM Item_factura if_totJOIN Factura f_tot ON if_tot.item_tipo = f_tot.fact_tipo 
                          AND if_tot.item_sucursal = f_tot.fact_sucursal 
                          AND if_tot.item_numero = f_tot.fact_numero
                          WHERE YEAR(f_tot.fact_fecha) > 2020
                         ) AS DECIMAL(10,2)) AS porcentaje_total_periodo

                         FROM Producto p
JOIN Item_Factura ifa ON p.prod_codigo = ifa.item_producto
JOIN Factura f ON ifa.item_tipo = f.fact_tipo 
              AND ifa.item_sucursal = f.fact_sucursal 
              AND ifa.item_numero = f.fact_numero
              WHERE YEAR(f.fact_fecha) > 2020


              WHERE EXISTS(
              SELECT  1
              FROM Item_Factura if1
              JOIN Factura f1 ON if1.item_tipo = f1.fact_tipo AND if1.item_sucursal = f1.fact_sucursal AND if1.numero = f1.fact_numero
              WHERE if1.item_producto = p.prod_codigo
              AND YEAR(f1.fact_fecha) > 2020
              AND EXISTS(
              SELECT 1
              FROM Item_Factura if2
              JOIN Factura f2 ON if2.item_tipo = f2.fact_tipo AND if2.item_sucursal = f2.fact_sucursal AND if2.item_numero = f2.fact_numero
              WHERE if2.item_producto = p.prod_codigo
              AND YEAR(f2.fact_fecha) = YEAR(f1.fact_fecha) + 1
              )
              AND EXISTS (
          SELECT 1 
          FROM Item_Factura if3
          JOIN Factura f3 ON if3.item_tipo = f3.fact_tipo AND if3.item_sucursal = f3.fact_sucursal AND if3.item_numero = f3.fact_numero
          WHERE if3.item_producto = p.prod_codigo 
            AND YEAR(f3.fact_fecha) = YEAR(f1.fact_fecha) + 2
      )
)
GROUP BY p.prod_codigo, p.prod_detalle
ORDER BY p.prod_detalle ASC;










     

  
 
