-- La comisión que cobra el sistema de recarga del transporte.
--
-- Recargar la tarjeta del bus cuesta una comisión fija por operación, así que recargar de a
-- poco sale más caro que hacerlo de una vez. Ese cargo no aparecía en ningún sitio: el gasto de
-- transporte reflejaba solo los pasajes, y la comisión se perdía entre las compras sueltas o
-- directamente no se apuntaba.
--
-- Va en la configuración de transporte del mes, junto al valor del pasaje, porque es del mismo
-- tipo de dato: una tarifa que el sistema cobra y que puede cambiar.

ALTER TABLE transport_configs
    ADD COLUMN comision_recarga numeric(10,2) NOT NULL DEFAULT 0;

ALTER TABLE transport_configs
    ADD CONSTRAINT ck_transport_configs_comision CHECK (comision_recarga >= 0);

-- A quien ya tenga meses creados se le deja en cero: es lo que había hasta ahora, y cambiarlo
-- por su cuenta alteraría cifras que ya se dieron por buenas.
