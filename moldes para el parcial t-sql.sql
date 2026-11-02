(Uso: Para rechazar operaciones indebidas, 
simular UNIQUE, evitar borrados con stock, límites de compra, etc.)

CREATE TRIGGER TR_ValidarRegla
ON TablaVigilada                -- DÓNDE se hace la acción (Producto, Item_Factura, etc.)[cite: 1, 3]
AFTER INSERT, UPDATE, DELETE    -- CUÁNDO (elegir según el enunciado)[cite: 1, 3]
AS
BEGIN
    SET NOCOUNT ON;

    -- Validación 1: Comparar contra datos ya existentes en la base
    IF EXISTS (
        SELECT 1
        FROM TablaFisica t
        JOIN inserted i ON t.clave = i.clave
        WHERE ... CondicionQueRompeLaRegla ...
    )
    -- Validación 2 (Opcional): Si hay riesgo de repetidos dentro del lote
    OR EXISTS (
        SELECT 1
        FROM inserted
        GROUP BY columna_que_debe_ser_unica
        HAVING COUNT(*) > 1
    )
    BEGIN
        RAISERROR('Mensaje explicativo del rechazo.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;
END;

Trigger de Consistencia / Actualización Directa
(Uso: Descontar stock al vender, sumar totales, imputar movimientos en otra tabla)

CREATE TRIGGER TR_ActualizarSaldo
ON Item_Factura
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Opción limpia y segura para lotes: tabla temporal en memoria
    DECLARE @resumen TABLE (
        id CHAR(8),
        cantidad DECIMAL(12,2)
    );

    -- 1. Agrupar lo que acaba de entrar en inserted
    INSERT INTO @resumen (id, cantidad)
    SELECT item_producto, SUM(item_cantidad)
    FROM inserted
    GROUP BY item_producto;

    -- 2. Impactar directamente en la tabla destino
    UPDATE s
    SET s.stoc_cantidad = s.stoc_cantidad - r.cantidad
    FROM STOCK s
    JOIN @resumen r ON s.stoc_producto = r.id
    WHERE s.stoc_deposito = '00';
END;

Trigger de Tabla Acumulada / Histórica en Tiempo Real
(Uso: Mantener permanentemente actualizada una tabla resumen ante altas, bajas o modificaciones)

CREATE TRIGGER TR_SincronizarAcumulados
ON Item_Factura
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Capturar todas las claves que cambiaron (altas, bajas o updates)
    DECLARE @afectados TABLE (
        id CHAR(8),
        periodo INT
    );

    INSERT INTO @afectados
    SELECT DISTINCT i.item_producto, YEAR(f.fact_fecha)*100 + MONTH(f.fact_fecha)
    FROM inserted i
    JOIN Factura f ON i.item_tipo = f.fact_tipo AND i.item_sucursal = f.fact_sucursal AND i.item_numero = f.fact_numero
    UNION
    SELECT DISTINCT d.item_producto, YEAR(f.fact_fecha)*100 + MONTH(f.fact_fecha)
    FROM deleted d
    JOIN Factura f ON d.item_tipo = f.fact_tipo AND d.item_sucursal = f.fact_sucursal AND d.item_numero = f.fact_numero;

    -- 2. Recalcular y sincronizar con MERGE
    MERGE INTO TablaAcumulada AS Destino
    USING (
        SELECT 
            af.id,
            af.periodo,
            SUM(ifa.item_cantidad) AS total_cant,
            MAX(ifa.item_precio)   AS precio_max,
            MIN(ifa.item_precio)   AS precio_min,
            SUM(ifa.item_cantidad * ifa.item_precio) AS total_monto
        FROM (SELECT DISTINCT id, periodo FROM @afectados) af
        JOIN Factura f ON (YEAR(f.fact_fecha)*100 + MONTH(f.fact_fecha)) = af.periodo
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

    -- 3. Limpieza: Si se borraron todas las ventas de ese período, eliminar la fila acumulada
    DELETE ta
    FROM TablaAcumulada ta
    JOIN (SELECT DISTINCT id, periodo FROM @afectados) af 
        ON ta.id = af.id AND ta.periodo = af.periodo
    WHERE NOT EXISTS (
        SELECT 1 
        FROM Factura f
        JOIN Item_Factura ifa ON ifa.item_tipo = f.fact_tipo AND ifa.item_sucursal = f.fact_sucursal AND ifa.item_numero = f.fact_numero
        WHERE ifa.item_producto = af.id
          AND (YEAR(f.fact_fecha)*100 + MONTH(f.fact_fecha)) = af.periodo
    );
END;


Stored Procedure con Manejo de Transacciones
(Uso: Cuando piden crear tablas nuevas, registrar compras masivas o múltiples pasos donde todo debe guardarse o nada)

CREATE PROCEDURE dbo.sp_OperacionTransaccional
    @parametro1 TIPO_DATO,
    @parametro2 TIPO_DATO
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Operación sobre la primera tabla (ej. INSERT compra)
        -- ...
        
        -- 2. Operación sobre la segunda tabla (ej. UPDATE stock)
        -- ...

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