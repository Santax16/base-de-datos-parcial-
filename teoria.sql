1. La lectura del diagrama (Claves y Navegación)Antes de escribir una sola línea de código, debes saber "caminar" por las tablas:   Identificar PK (Clave Primaria): El campo único de la tabla.
Identificar FK (Clave Foránea): La columna que apunta a otra tabla.
Detectar claves compuestas: Como Factura e Item_Factura, donde una sola columna no alcanza y la relación necesita 3 campos (tipo, sucursal, numero).  
Identificar relaciones 1 a N: Saber qué tabla multiplica a cuál (ej: un producto tiene muchas ventas y muchos depósitos).

2. Los tipos de JOINSaber cuándo incluir filas incompletas:
INNER JOIN (o JOIN): Exige que el dato exista en ambos lados. Si un producto nunca se vendió, desaparece.
LEFT JOIN: Mantiene todas las filas de la tabla principal aunque no tengan movimientos en la secundaria (fundamental cuando piden "para todos los artículos" o "para todos los clientes").
Auto-unión (Self-Join): Unir una tabla consigo misma (clave para ejercicios con jefes y empleados como empl_jefe = empl_codigo, o para comparar ventas de pares de productos). 

3. Agrupación y Funciones de Agregación (GROUP BY)Entender cómo resumir muchas filas en una sola métrica:SUM():
Sumar importes o unidades (SUM(item_cantidad)).
COUNT(): Contar filas o registros no nulos.
COUNT(DISTINCT columna): Contar elementos sin repetir (ej: cantidad de clientes distintos que compraron un producto, o cantidad de productos diferentes).
AVG(): Sacar promedios (AVG(stoc_cantidad)).   
MAX() / MIN(): Obtener extremos (la mayor venta, menor precio).   
Regla estricta: Si agrupas, toda columna en el SELECT que no tenga función de agregado debe estar en el GROUP BY. 

4. Filtrado: WHERE vs HAVINGSaber en qué momento exacto descartar datos:
WHERE: Filtra filas individuales antes de agrupar (fechas, años, códigos fijos, importes por fila). 
HAVING: Filtra grupos después de agrupar, usando el resultado de una función (ej: "que hayan vendido más de 100 unidades", "que tengan stock promedio > 100").   

5. Subconsultas (Subqueries)Saber cuándo dejar de encadenar JOINs y hacer una pregunta aislada:
Subconsulta correlacionada en el SELECT: Para calcular un dato auxiliar fila por fila sin desarmar la estructura de la consulta principal (como contar componentes mientras miras el stock). 
Subconsulta en el WHERE:Con operadores: = (SELECT MAX(...)), > (SELECT AVG(...)).   Con pertenencia: IN (SELECT ...), NOT IN (...).   Con existencia: EXISTS (...), NOT EXISTS (...).

6. Condicionales dentro de agregaciones (CASE WHEN)Es el truco para resolver ejercicios que comparan dos períodos o dos categorías en la misma consulta (como el ejercicio 5 comparando 2012 contra 2011):  
SQLSUM(CASE WHEN YEAR(fact_fecha) = 2012 THEN item_cantidad ELSE 0 END)
Esto te permite sumar de manera selectiva sin tener que partir la consulta en varias tablas. 

7. Manejo de Fechas y Nulos en SQL ServerFunciones que aparecen en casi todos los enunciados:ISNULL(campo, 0):
Reemplazar un valor nulo para que no rompa sumas ni muestre celdas vacías cuando la consigna dice "no se deberán visualizar NULLs".  
YEAR(fecha) / MONTH(fecha): Extraer partes de una fecha.   
DATEPART(quarter, fecha): Para ejercicios que piden trimestres (1 a 4).   
TOP n con ORDER BY: Para pedir rankings ("los 10 más vendidos", "los 3 mejores").   

TODO EN SQL SON CONJUNTO DE FICHAS
ponele que la base de datos es un mueble con archivadores
- cada tabla es una caja con fichas rectangulares (filas/tuplas)
- cada ficha tiene casilleros fijos : nombre precio codigo (columnas/atributos)

en sql se piensa distinto por que es declarativo y esta basado en conjuntos 
yo describo las propiedades del conjunto que quiero obtener y el motor se encarga de buscarlo 

QUE SIGNIFICA CADA OPERACION 

- A 
FROM Cliente "quiero toda las fichas de la caja cliente "

- B 
JOIN : " Pegar fichas con cinta adhesiva"

 Existen los join por que en bdd relacionales la info esta separada para no repetir datos (normalizacion)

 . Tenes la caja facturas (con fecha y cliente)
 . Tenes la caja items_factura (con que productos se compraron)

 si vos haces 
  FROM Factura f
  JOIN Item_Factura ifa
  ON f.fact_numero = ifa.item_numero

  el motor hace lo siguiente:
  1. Toma una ficha de la caja factura
  2. Busca en la caja item_factura todas las fichas que tengan el mismo numero
  3. Las pega con cinta adhesiva, creando una ficha nueva y mas ancha que tiene los datos de factura y de item
  4. Si una factura tiene 3 items, de esa sola factura nacen 3 fichas compuestas 

- C
WHERE : "La tijera / colador de fichas"
una vez que las fichas estan en la mesa y pegadas en sus join, el where pasa como un colador 

WHERE clie_limite_credito >=1000
. agarra cada ficha pegada
. mira el casillero clie_limite_credito
. si es menor a 1000 la descarta 
. las fichas que sobreviven siguen en la mesa

- D el GROUP BY: "Hacer montoncitos "
ej te quedaron 1000 fichas de ventas

GROUP BY prod_codigo

el motor hace lo siguiente
1. agarra una caja organizadora con separadores
2. cada ficha que tenga el codigo P001 la pone en una pila 
3. Todas la que tengan P002 las pone en otra pila
4. al final ya no tenes 1000 fichas sueltas ahora por ej tendrias 50 montoncitos

por que nace la rgla de las funciones de agregacion?

una vez que hiciste montoncitos ya no podes mirar los datos inviduales de una sola ficha . 
el motor solo puede responder preguntas sobre el monton en conjunto
¿ cuantas fichas hay en este monton? -> COUNT() COUNT(columna): Cuenta cuántas filas tienen un valor distinto de NULL en esa columna específica. Si en alguna fila esa columna está vacía (NULL), esa fila no se suma COUNT(*): Cuenta la cantidad total de filas (fichas) que hay en el conjunto, sin importar si alguna columna interna tiene nulos o no. Mira la existencia de la fila entera.
¿ cuanto suman los importes de todas las fichas del monton? -> SUM()
¿ cual es el promedio del monton? -> AVG()
¿ cual es el valor mas alto del monton ? -> MAX()
Si intentas pedir una columna que varia dentro del monton 

- E. el HAVING: "El colador de montoncitos"
el WHERE colo fichas individuales antes de armar los montones 
el HAVING es un segundo colador , pero actua sobre montones ya armados:
HAVING SUM(cantidad) > 100
. Pesa el monton completo
. si la suma de las fichas de ese monton es menor a 100 tira el monton a la basura

- F EL SELECT : "elegir que casilleros recortar para el reporte final"
el select es lo que se muestra al final
. de las fichas o montoncitos que sobrevivieron a todos los filtros, le digo de todos los casilleros que tienen estas fichas mostrame solo estas 2 columnas


Regla 1: La Regla del Grano
(¿De qué habla una sola fila?)Antes de escribir una sola letra de código, busca el sujeto de la oración
en el enunciado:"Mostrar para cada cliente..." 
$\rightarrow$ Tu tabla principal es Cliente y agrupas por cliente.   
"Para todos los rubros..." $\rightarrow$ Tu tabla principal es Rubro.
"Para cada producto..." $\rightarrow$ Tu tabla principal es Producto.
Por qué importa: Si sabes cuál es el sujeto,
sabes qué poner en el FROM principal y qué define tus montoncitos.

Regla 2: El "Detector de Ramas" (Cuándo NO hacer JOIN)Miras el mapa del DER.
Si te piden datos que salen hacia dos lados opuestos del mismo sujeto:
Hacia la izquierda: Ventas (Item_Factura).
Hacia la derecha: Depósitos/Stock (STOCK) o Componentes (Composicion).
La trampa: Si juntas las dos ramas en el FROM con JOIN, 
se produce una multiplicación cruzada ($M \times N$) y te revienta cualquier SUM, AVG o COUNT.
La regla: Quédate con una sola rama en el FROM principal,
y la otra rama resuélvela mediante una subconsulta aislada en el SELECT.

¿Dónde vive el número de ticket de cada renglón? En Item_Factura (item_tipo, item_sucursal, item_numero).

Como la consigna solo pide que hayan sido vendidos en la misma factura
(sin pedir fecha, cliente ni total),
alcanza con cruzar Item_Factura consigo misma mediante su clave de factura.