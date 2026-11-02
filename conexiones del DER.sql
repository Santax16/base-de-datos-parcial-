conexiones del DER QUE TENGO QUE SABER 

1. Ventas y Facturación (La clave compuesta clásica)

Factura con Item_Factura (Son 3 campos obligatorios):

JOIN Item_Factura ifa 
    ON  f.fact_tipo = ifa.item_tipo
    AND f.fact_sucursal = ifa.item_sucursal
    AND f.fact_numero = ifa.item_numero

//

Item_Factura con Producto:

JOIN Producto p 
    ON ifa.item_producto = p.prod_codigo

 //

Factura Con Cliente :
JOIN Cliente c 
    ON f.fact_cliente = c.clie_codigo

 //

 Factura con Empleado (El vendedor)

 JOIN Empleado e 
    ON f.fact_vendedor = e.empl_codigo

2. Inventario y Depósitos
Producto con STOCK:

JOIN STOCK s 
    ON p.prod_codigo = s.stoc_producto

  //  
 STOCK con DEPOSITO:

 JOIN DEPOSITO d 
    ON s.stoc_deposito = d.depo_codigo

  //
DEPOSITO con Empleado (El encargado del depósito):

JOIN Empleado e 
    ON d.depo_encargado = e.empl_codigo

   
   3. Clasificación de Artículos (Maestros simples)
    
    Producto con Rubro:
    
    JOIN Rubro r 
    ON p.prod_rubro = r.rubr_id

    //

    Producto con Familia:
    
    JOIN Familia fam 
    ON p.prod_familia = fam.fami_id
    
    //

    Producto con Envases:

    JOIN Envases env 
    ON p.prod_envase = env.enva_codigo


    4. Tablas Recursivas y Estructura Jerárquica
    
    
    Composicion con Producto (Relación de combos/ensamblados)  

    Si buscas los componentes que forman el producto principal (padre):

    JOIN Composicion c 
    ON p.prod_codigo = c.comp_producto

    Si buscas en qué combos se usa un componente como parte (hijo):

    JOIN Composicion c 
    ON p.prod_codigo = c.comp_componente

    //
    

    Empleado con Empleado (Jefe y Subordinado)

    FROM Empleado e
    JOIN Empleado j 
    ON e.empl_jefe = j.empl_codigo

    //

   Cliente con Empleado (Vendedor asignado al cliente)

   JOIN Empleado e 
    ON c.clie_vendedor = e.empl_codigo

    //

    Empleado con Departamento:

    JOIN Cliente c 
    ON f.fact_cliente = c.clie_codigo