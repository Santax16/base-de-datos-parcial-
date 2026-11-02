T-SQL

1. VARIABLES en T-SQL DECLARACION Y ASIGNACION

EN T-SQL todas las variables llevan un arroba (@) al principio de su nombre

ej 
-- 1 Declarar la variable con su tipo de dato
DECLARE @total_ventas DECIMAL(12,2);
DECLARE @cliente_id CHAR(6);

--2 Asignarle un valor fijo
SET @cliente_id = '000123';

--3 Guardar el resultado de una consulta dentro de una variable
SELECT @total_ventas = SUM(fact_total)
FROM Factura
WHERE fact_cliente = @cliente_id;

--4 Mostrar o inspeccionar su valor
PRINT @total_ventas;

Regla de oro: Cuando asignas una variable mediante un
SELECT @variable = columna ..., la consulta debe devolver un único valor (escalar). 
Si devuelve 10 filas,
la variable se quedará únicamente con el valor de la última fila procesada.

2. Estructuras de control de flujo: if/else y begin ... end
En T-sql las llaves {...} de otro lenguajes se reemplaazan por begin y end. 
Si tu if tiene mas de uan linea de codigo adentro tu begin ... end es obligatorio

If @total_ventas > 50000
Begin 
PRINT 'CLIENTE VIP';
END
ELSE 
BEGIN
 PRINT ' CLIENTE REGULAR';
END

3. TRIGGERS (DISPARADORES)
Un triggers es un bloque de codigo que	SQL Server ejecuta automaticamente cuando ocurre
un evento de modificacion de datos sobre una tabla : INSERT, UPDATE O DELETE

se toman normalmente con dos propositos
1- mantener consistencia/ actualizar totales: por ejemplo, al insertar un Item_factura,
descontar el stock en la tabla STOCK o actualizar el fact_total de la factura.
2- validar reglas de negocio complejas: ej, si el cliente no tiene credito suficiente,
o si se intenta vender un producto sin stock, abortar la transaccion

Las tablas magicas : inserted y deleted

Dentro de un trigger existen dos tablas temporales en memoria provistas por el motor:

INSERT: 
que contiene inserted?
las filas nuevas que acaban de entrar 
que contien deleted?
vacia

DELETE:
que contiene inserted?
vacia
que contiene deleted?
las filas viejas que se estan borrando

UPDATE:
que contiene el inserted?
valores nuevos de las filas modificadas
que contiene el deleted?
los valores viejos antes del cambio

un UPDATE es tecnicamente un delete de la fila vieja seguido de un insert de la nueva

4. trampa mortal de los triggers en parciales : procesamiento por lotes 
el error mas comun es escribir

-- error asume q se inserta una fila a la vez
SELECT @prod = item_producto, @cant = item_cantidad FROM inserted ;

Si un sistema hace un insert into item_factura SELECT ... e ingresan 200 items en una sentencia,
inserted tendra 200 filas. Si usas variables sueltas, solo evaluaras una y el trigger fallara

el codigo debe operar sobre conjuntos(haciendo join con inserted o deleted)

5. Estructura de una base de un trigger de consistencia:

imagina esta regla de negocio
"cada vez que se inserta un renglon en item_factura, descontar automaticamente la cantidad vendidad del stock en el deposito '00'."

CREATE TRIGGER TR_ItemFactura_DescontarStock
ON Item_factura
AFTER INSERT
AS
BEGIN
 SET NOCOUNT ON; -- evita que los conteos de filas interfieran

 -- actualizamos el stock haciendo join directo con la tabla inserted
 UPDATE s
 SET s.stoc_cantidad = s.stoc_cantidad - ins.item_cantidad
 FROM STOCK s 
 JOIN inserted ins
  ON s.stoc_producto = ins_item_producto
  WHERE s.stoc_deposito = '00';
  END;


--
1. ¿Por qué ON Item_Factura?
En SQL, un trigger es un sensor de alarma, y la base de datos necesita saber en qué puerta poner ese sensor.

Si escribes ON Item_Factura, le estás diciendo a SQL Server:

«Este sensor vigila exclusivamente la tabla Item_Factura. Si alguien toca Cliente o Empleado,
no hagas nada. Despiértate únicamente cuando ocurra algo en Item_Factura».


2. ¿Qué significa AFTER (y qué alternativa existe)?
AFTER define el momento exacto en el que salta el código:
AFTER INSERT (o AFTER UPDATE, AFTER DELETE):
Significa: «Deja que la operación entre a la tabla primero; una vez que las filas ya tocaron la base, ejecuta mi código»
.Es el que se usa el 90% de las veces para:
Descontar stock acumulado.
Actualizar totales de facturas o comisiones.
Auditar cambios.(Si adentro del código detectas que algo no cumplía una regla de negocio, ejecutas un ROLLBACK TRANSACTION y deshaces todo lo que se acababa de insertar).

La alternativa: INSTEAD OF:

Significa «En lugar de». Le dice al motor: «Frena la inserción/borrado; no la ejecutes. Corre mi código en su lugar».

Se usa, por ejemplo, en el Ejercicio 10: 
"ante el intento de borrar un artículo verifique que no exista stock y si es así lo borre en caso contrario que emita un mensaje de error".
Si tiene stock, ni siquiera dejas que empiece el borrado.


3. ¿Qué hace SET? (Los dos usos en T-SQL)
SET es la orden de asignar o configurar un valor. Se usa en dos lugares muy distintos:

Uso A: Asignar valor a una variable o columna
Es el equivalente al signo = en programación tradicional:

Uso B: Configurar el entorno con SET NOCOUNT ON
Cuando ejecutas cualquier consulta en SQL Server (INSERT, UPDATE),
el motor devuelve por abajo un mensaje interno: (1 filas afectadas).


  RESUMEN VISUAL DE LA ANATOMIA DE UN TRIGGER 
  CREATE TRIGGER TR_ControlVenta   -- 1. Nombre del trigger
ON Item_Factura                  -- 2. DÓNDE está la alarma (la tabla vigilada)
AFTER INSERT                     -- 3. CUÁNDO suena (después de que inserten filas)
AS
BEGIN
    SET NOCOUNT ON;              -- 4. Buenas prácticas de ejecución

    -- 5. TU CÓDIGO (usando las tablas 'inserted' o 'deleted')
    
END;


¿Cómo darte cuenta en un parcial? (La regla práctica) DEL SET NOCOUNT ON
Si estás haciendo un SELECT puro: no va.

Si estás creando una FUNCTION: no se permite (las funciones no pueden alterar el estado de sesión).

Si estás creando un TRIGGER o un STORED PROCEDURE: va por defecto siempre.


--


herramientas para resolver el ej1

1 Estructura de una funcion escalar
a diferencia de un trigger o un procedure una funcion escalar recibe parametros, hace un calculo y devuelve un unico valor con RETURN

ej

CREATE FUNCTION dbo.NombreFuncion
(
 @parametro1 TIPO_DATO,
 @parametro2 TIPO_DATO
)
RETURNS VARCHAR(100) -- que tipo de dato devuelve
AS
BEGIN
   DECLARE @resultado VARCHAR(100)
   -- logica de calculo

   RETURN @resultado; -- siempre termina devolviendo la variable
   END ; 

2. Conversion de numeros a texto (STR O CAST)
para armar la frase "ocupacion del deposito 75% no podes pegar un numero decimal directamente en un texto
- calculas el procentaje: (@cantidad * 100) / @limite
- lo convertis a texto sin decimales

CONCAT('OCUPACION DEL DEPOSITO', CAST(CAST((@cantidad * 100 / @limite) AS INT) AS VARCHAR), '%')
O USANDO STR 
'OCUPACION DEL DEPOSITO ' + LTRIM(STR((@cantidad * 100.0) / @limite, 5, 0)) + ' %'


EN SQL DECIMAL(p,s) define numeros con coma exactos los dos numeros entre parentesis representan la precision y la escala

1. el primer numero 12 es la precision
- cantidad total absoluta de digitos que puede tener el numero en total
2. la escala esta para los decimales los de la derecha de la coma

La herramienta que nos falta: 
¿Cómo frenar y tirar error?Para que un trigger diga:
"¡Pará la mano, este producto tiene stock!",
usamos dos órdenes:RAISERROR('Mensaje de error', 16, 1);
(o THROW):Muestra el cartel rojo de error en la pantalla.

1. ¿Cómo funciona IF EXISTS?
IF EXISTS es la forma más rápida y limpia que tiene SQL Server para responder a la pregunta:

"¿Hay al menos una fila que cumpla esta condición?"

ROLLBACK TRANSACTION;:Es el botón de marcha atrás. Deshace el borrado y deja la base de datos intacta,
como si nadie hubiera intentado borrar nada.

2. ¿Qué significan el 16 y el 1 en RAISERROR?('No se puede eliminar el artículo porque posee stock.', 16, 1);
El primer número ($16$): La Severidad (Nivel de gravedad)Le indica a SQL Server qué tan grave es el problema.
En SQL Server los niveles van del 0 al 25:0 al 10: Mensajes informativos (no son errores, solo advertencias).
11 al 16: Errores provocados por el usuario o reglas de negocio (por ejemplo: falta stock, saldo insuficiente, clave duplicada).
17 al 25: Errores críticos de software o hardware (se cayó el disco, memoria corrupta).
Para el examen: El número 16 es el estándar obligatorio para decir: "Es un error de regla de negocio corregible por el usuario"

El segundo número ($1$): El Estado (State)Es un número entero entre 1 y 127 que sirve como identificador interno del punto exacto
donde falló el código.Si en un mismo trigger tuvieras 3 validaciones distintas con mensajes parecidos,
podrías ponerle estado 1 a la primera, estado 2 a la segunda y estado 3 a la tercera para rastrear en los logs cuál saltó.
En los parciales no se audita esto: se coloca 1 por convención.Tu apunte mental para el examen:SQLRAISERROR('Texto del error', 16, 1);
ROLLBACK TRANSACTION;
16 = Severidad (error de regla de negocio).1 = Estado estándar.ROLLBACK TRANSACTION = Deshace la operación para que nada quede guardado.

1. QUE ES UN LOTE EN LA VIDA REAL
un lote es simplemente mas de una fila ingresando, modificandose o borrandose al mismo tiempo en una sola sentencia sql

CASO de 1 sola fila:
una persona en la caja escanea un alfajaor se ejecuta:
INSERT INTO Item_Factura VALUES ('A', '0001', '00000001', 'PROD01', 2, 500);

Aca inserted tiene 1 fila

CASO POR LOTES (multiples filas juntas)
una empresa procesa el cierre del dia  o un camion descarga mercaderia o se cargan todos los renglones de una factura de golpe mediantes
script masivo

INSERT INTO Item_factura(item_sucursal, item_numero, item_producto, item_cantidad)
SELECT ... FROM CargaMasiva;

aca ingresan 100 filas juntas por lo tanto inserted tiene 100 filas juntas

la clave es tratar al inserted y deleted como si fueran tablas comunes y corrientes con el JOIN 

las 3 formas de usar inserted deleted

1. validar/bloquear(IF EXISTS  + JOIN)
no modificas nada, cruzas la tabla en memoria contra la base para verificar si existe alguna fila que viole la regla de negocio si el join
encuentra algo lo cancelas con el rollback 

IF EXISTS (
    SELECT 1 
    FROM STOCK s
    JOIN deleted d ON s.stoc_producto = d.prod_codigo
    WHERE s.stoc_cantidad > 0
)
BEGIN
    RAISERROR('No se puede borrar: tiene stock.', 16, 1);
    ROLLBACK TRANSACTION;
END;

2. para modificar directo (UPDATE ... FROM ... JOIN)
emparejas la tabla fisica con las filas recien afectadas para sumar, restar o sincronizar saldos de forma masiva en una sola sentencia:

UPDATE s
SET s.stoc_cantidad = s.stoc_cantidad - ins.item_cantidad
FROM STOCK s
JOIN inserted ins ON s.stoc_producto = ins.item_producto
WHERE s.stoc_deposito = '00';

3. para modificar lotes agrupados ( UPDATE .. FROM .. JOIN (SUBQUERY GROUP BY))

si dentro de las filas afectadas un mismo identificador puede repetirse multiples veces ej mismo producto vendido varios renglones
agrupas por inserted antes de unirlo con la tabla destino




1. ¿Qué es un CONSTRAINT y para qué sirve?
Un CONSTRAINT (restricción) es una regla de integridad estricta declarada en la definición de la tabla (a nivel de base de datos)
para impedir que se guarden datos inválidos, inconsistentes o duplicados. 
¿Para qué sirve?
Garantiza que la base de datos rechace automáticamente cualquier intento de INSERT o UPDATE que viole la regla,
sin necesidad de escribir código procedural ni triggers. 
Tipos principales:PRIMARY KEY: Identifica cada fila de forma única y no permite NULL.
FOREIGN KEY: Asegura que un valor exista en otra tabla (integridad referencial).
UNIQUE: Impide que una columna tenga valores repetidos (como en el examen donde pedían simularlo).   
CHECK: Valida condiciones lógicas simples (por ejemplo: CHECK (precio > 0)).
NOT NULL: Obliga a que siempre haya un dato en ese campo.
Ejemplo práctico:
CREATE TABLE Historial_Bajo_Stock (
    hbs_producto CHAR(8) NOT NULL,
    hbs_anio INT NOT NULL,
    hbs_dias INT NOT NULL DEFAULT 1,
    -- CONSTRAINT que define la clave primaria compuesta:
    CONSTRAINT PK_Historial PRIMARY KEY (hbs_producto, hbs_anio)
);


2. ¿Qué es MERGE y para qué sirve?La sentencia MERGE es una instrucción de SQL (formalmente llamada UPSERT: Update + Insert)
que permite sincronizar dos tablas en un único comando atómico, evaluando si una fila ya existe o no.
¿Para qué sirve?
Evita tener que escribir sentencias separadas como un IF EXISTS (...) UPDATE ... ELSE INSERT ... o hacer bucles.
Con un solo MERGE, el motor evalúa todo el lote y decide qué actualizar, qué insertar o qué eliminar al mismo tiempo.   
Estructura básica:

MERGE INTO TablaDestino AS Destino
USING TablaOrigen AS Origen
ON (Destino.clave = Origen.clave)
WHEN MATCHED THEN
    UPDATE ...
WHEN NOT MATCHED BY TARGET THEN
    INSERT ...;

3. ¿Qué es TARGET y para qué sirve?
En una sentencia MERGE, el TARGET (destino) es la tabla física real que vas a modificar o sincronizar. 
¿Para qué sirve?
Indica cuál es el receptor de los cambios (la tabla que va a recibir los INSERT, UPDATE o DELETE).
En el código:
Aparece en la cabecera junto a MERGE INTO:
MERGE INTO Historial_Bajo_Stock AS Destino   -- Este es el TARGET
USING ( ... ) AS Origen                      -- Este es el SOURCE (origen de datos)
Se usa también en las cláusulas de comparación:
WHEN NOT MATCHED BY TARGET: Significa "el dato viene en el origen pero todavía NO existe en el Target (destino)"
$\rightarrow$ Corresponde hacer un INSERT.   

4. ¿Qué es MATCHED y para qué sirve?
MATCHED (coincidencia) es la condición de evaluación dentro del MERGE que indica que la clave buscada ya se encontró en la tabla destino (TARGET).
¿Para qué sirve?
Determina el camino a seguir cuando el registro ya existe en la base de datos (por ejemplo, para actualizar acumuladores,
saldos o fechas en vez de intentar insertar una fila duplicada).
Comportamiento:WHEN MATCHED THEN UPDATE ...: Si la condición del ON dio verdadero (el producto y año ya estaban guardados), ejecuta una actualización sobre las columnas del TARGET.
WHEN MATCHED AND (condición adicional) THEN ...: Permite agregar un filtro extra antes de actualizar
(por ejemplo: WHEN MATCHED AND Destino.hbs_ultima_fecha < @hoy THEN UPDATE... para no sumar el mismo día dos veces).
WHEN NOT MATCHED THEN INSERT ...: Si no hubo coincidencia (la fila no existe), toma los datos del origen y los inserta. 