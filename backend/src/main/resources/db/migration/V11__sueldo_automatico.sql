-- Rediseño v2, fase 8: sueldo base automático.
--
-- Un sueldo en otra moneda cambia con la TRM. Marca los meses cuyo sueldo base viene de la
-- proyección de un sueldo, para recalcularlos solos cuando cambia la tasa. Editar el sueldo a
-- mano o anotar lo que de verdad llegó quita la marca: entonces manda el dato real.
ALTER TABLE budget_months
    ADD COLUMN sueldo_automatico boolean NOT NULL DEFAULT false;
