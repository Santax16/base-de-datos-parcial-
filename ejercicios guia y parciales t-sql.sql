-- EJ 1
CREATE FUNCTION dbo.fn_estado_deposito
(
 @articulo  char(8),
 @deposito char(2)
)
RETURNS VARCHAR(100)
AS
BEGIN
-- nuestras cajas de memoria
DECLARE @cantidad DECIMAL(12,2);
DECLARE @limite DECIMAL(12,2);
DECLARE @porcentaje DECIMAL(5,2)
DECLARE @resultado VARCHAR(100);
-- paso 1: buscamos la ficha en al tabla stock

SELECT 
@cantidad = s.stoc_cantidad
@limite = s.stoc_stock_maximo
FROM STOCK s
WHERE s.stoc_producto = @articulo
AND s.stoc_deposito = @deposito;

-- paso 2: la regla del negocio
IF @cantidad > @limite
BEGIN
   SET @resultado = 'DEPOSITO COMPLETO'
END
ELSE
BEGIN
-- calculamos el porcentaje 
   SET @porcentaje = (@cantidad * 100) / @limite;
-- armamos la frase 

SET @resultado = CONCAT('OCUPACION DEL DEPOSITO ', CAST(CAST(@porcentaje AS INT) AS VARCHAR), ' %');
    END

-- paso 3 entregamos la respuesta

RETURN @resultado;
END;

--EJ 10

CREATE TRIGGER TR_BorrarProducto_ValidadStock
ON Producto 
AFTER DELETE
AS
BEGIN
 SET NOCOUNT ON;

 -- Verificamos que si existe al menos un producto de los elminados que tenga stock
 IF EXISTS(
  SELECT 1 
  FROM STOCK s
  JOIN deleted d ON s.stoc_producto = d.prod_codigo
  WHERE s.stoc_cantidad > 0
  )
  BEGIN
  -- si encontramos stock, tiramos error y cancelamos todo
  RAISERROR('NO SE PUEDE ELIMINAR ARTICULO POR QUE POSEE STOCK',16,1);
  ROLLBACK TRANSACTION;
  RETURN;
  END;
END;


EJ DE PARCIAL 

CREATE TRIGGER TR_Producto_Detalle_Unique
ON Producto
AFTER INSERT, UPDATE
AS
BEGIN
 SET NOCOUNT ON;
 -- CASO 1 : INTENTAR PONER UN DETALLE QUE YA TIENE OTRO PRODUCTO EN LA TAB
 -- CASO 2: EN LA MISMA SENTENCIA INSERTAN DOS PRODUCTOS CON EL MISMO DETALLE
 IF EXISTS(
  SELECT 1
  FROM Producto p
  JOIN inserted i
    ON p.prod_detalle = i.prod_detalle
    AND p.prod_codigo <> i.prod_codigo
  ) 
  OR EXISTS (
  select 1
  FROM inserted
  GROUP BY prod_detalle
  HAVING COUNT(*) > 1
  )
  BEGIN 
  RAISERROR('OPERACION CANCELADA: YA EXISTE UN PRODUCTO CON ESE DETALLE (violacion unique).'
  ROLLBACK TRANSACTION;
  RETURN;
  END;
  END;

  PASO 3 EJ 16
  CREATE TRIGGER TR_ItemFactura_DescontarStockSimple
  ON Item_Factura 
  AFTER INSERT
  AS
  BEGIN
   SET NOCOUNT ON;


  UPDATE s
  SET s.stoc_cantidad = s.stoc_cantidad - ins.item_cantidad
  FROM STOCK s
  JOIN (
  SELECT
  ins.item_producto
  SUM(ins.item_cantidad) AS total_vendido
  FROM inserted ins
  GROUP BY i.item.producto)
  ventas ON s.stoc_producto = ventas.item_producto
  WHERE s.stoc_deposito = '00';
  END ;

  -- 1. Tabla de Proveedores
CREATE TABLE Proveedor (
    prov_codigo CHAR(6) PRIMARY KEY,
    prov_razon_social VARCHAR(100) NOT NULL
);

-- 2. Tabla para registrar las Compras realizadas
CREATE TABLE Compra (
    comp_numero INT IDENTITY(1,1) PRIMARY KEY,
    comp_fecha DATETIME NOT NULL,
    comp_proveedor CHAR(6) NOT NULL FOREIGN KEY REFERENCES Proveedor(prov_codigo),
    comp_producto CHAR(8) NOT NULL,
    comp_deposito CHAR(2) NOT NULL,
    comp_cantidad DECIMAL(12,2) NOT NULL,
    comp_precio DECIMAL(12,2) NOT NULL
);

CREATE PROCEDURE dbo.sp_RegistrarCompraYActualizarStock
    @proveedor CHAR(6),
    @producto CHAR(8),
    @deposito CHAR(2),
    @cantidad DECIMAL(12,2),
    @precio DECIMAL(12,2)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Operación sobre la primera tabla (ej. INSERT compra)
        IF NOT EXISTS(SELECT 1 FROM STOCK WHERE stoc_producto = @producto AND stoc_deposito = @deposito)
        BEGIN       
        -- ...
        INSERT INTO STOCK (stoc_producto, stoc_deposito, stoc_cantidad, stoc_punto_reposicion, stoc_stock_maximo)
            VALUES (@producto, @deposito, 0, 0, 1000);
        END;
        
        -- 2. Operación sobre la segunda tabla (ej. UPDATE stock)
        -- ...
        INSERT INTO Compra (comp_fecha, comp_proveedor, comp_producto, comp_deposito, comp_cantidad, comp_precio)
        VALUES (GETDATE(), @proveedor, @producto, @deposito, @cantidad, @precio);

        -- 3. Aumento del stock físico por la mercadería ingresada
        UPDATE STOCK
        SET stoc_cantidad = stoc_cantidad + @cantidad
        WHERE stoc_producto = @producto 
          AND stoc_deposito = @deposito;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        -- Si cualquier sentencia falla, deshace todo
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- Informa el error que ocurrió
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH;
END;


EJ DE PARCIAL

CREATE TABLE Historial_bajo_stock(
hbs_producto CHAR(8) NOT NULL,
hbs_anio int NOT NULL,
hbs_dias INT NOT NULL DEFAULT 1,
hbs_ultimaFecha DATE NOT NULL,
CONSTRAINT PK_Historial_bajo_stock PRIMARY KEY (hbs_producto, hbs_anio)
);

CREATE TRIGGER TR_Control_Punto_Reposicion_Dep27
ON STOCK
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Filtramos únicamente los productos del depósito '27' que quedaron bajo el punto de reposición
    -- y que hoy no hayan sido ya contabilizados
    DECLARE @hoy DATE = CAST(GETDATE() AS DATE);
    DECLARE @anio INT = YEAR(GETDATE());

    -- Registramos o sumamos un día en la tabla histórica usando MERGE (Molde 3)
    MERGE INTO Historial_Bajo_Stock AS Destino
    USING (
        SELECT DISTINCT 
            i.stoc_producto AS producto
        FROM inserted i
        JOIN deleted d 
            ON i.stoc_producto = d.stoc_producto 
           AND i.stoc_deposito = d.stoc_deposito
        WHERE i.stoc_deposito = '27'
          AND i.stoc_cantidad < i.stoc_punto_reposicion
    ) AS Origen
    ON (Destino.hbs_producto = Origen.producto AND Destino.hbs_anio = @anio)
    
    -- Si ya existe registro de este producto en el año actual:
    -- Solo incrementamos los días si el evento no fue registrado hoy
    WHEN MATCHED AND Destino.hbs_ultima_fecha < @hoy THEN
        UPDATE SET 
            Destino.dias = Destino.dias + 1,
            Destino.hbs_ultima_fecha = @hoy

    -- Si es la primera vez en el año que cae por debajo del punto de reposición:
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (hbs_producto, hbs_anio, hbs_dias, hbs_ultima_fecha)
        VALUES (Origen.producto, @anio, 1, @hoy);
END;