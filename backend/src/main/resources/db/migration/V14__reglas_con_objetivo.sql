-- Registro automático, fase B: aceptar lo detectado.
--
-- Una regla o una sugerencia puede apuntar a una deuda concreta: «pagar a esta entidad es un
-- abono a esta deuda». Sin la deuda, la sugerencia de abonar no se podría aceptar de un toque.
ALTER TABLE detection_rules ADD COLUMN objetivo_id uuid;
ALTER TABLE detected_movements ADD COLUMN sugerencia_objetivo uuid;
