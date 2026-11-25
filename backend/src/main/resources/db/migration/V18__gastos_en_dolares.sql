-- Gastos fijos que se cobran en dólares (una suscripción de 20 USD).
--
-- Se guarda el monto en dólares; el valor en pesos se calcula con la TRM de la fuente de ingreso
-- en dólares y se recalcula cuando cambia, mientras el gasto siga pendiente. Una vez pagado
-- queda lo que de verdad se pagó.
ALTER TABLE expense_templates ADD COLUMN monto_usd numeric(10,2);
ALTER TABLE expenses ADD COLUMN monto_usd numeric(10,2);
