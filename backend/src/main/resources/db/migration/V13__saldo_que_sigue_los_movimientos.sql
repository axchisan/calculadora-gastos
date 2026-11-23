-- Los saldos de las cuentas siguen a lo que se apunta.
--
-- Antes el saldo de cada cuenta solo cambiaba al anotarlo a mano: una compra en efectivo bajaba
-- el disponible del mes pero no el efectivo de «Mis cuentas», y el total de Inicio se quedaba
-- atrás. Ahora se guarda el momento exacto en que se anotó cada saldo, y la app le suma lo que
-- se haya apuntado después.
ALTER TABLE accounts ADD COLUMN saldo_anotado_en timestamptz;

-- Hasta hoy, la última modificación de una cuenta era siempre anotar su saldo.
UPDATE accounts SET saldo_anotado_en = updated_at;

ALTER TABLE accounts ALTER COLUMN saldo_anotado_en SET NOT NULL;
