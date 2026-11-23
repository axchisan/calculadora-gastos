-- Rediseño v2, fase 6: «Te deben».
--
-- Lo que otros le deben al usuario se guarda como una deuda «a favor». Usa los mismos abonos,
-- pero en sentido contrario: un abono a una deuda a favor es un cobro, dinero que entra en el
-- mes, y su saldo no suma a lo que el usuario debe.
ALTER TABLE debts
    ADD COLUMN a_favor boolean NOT NULL DEFAULT false;
