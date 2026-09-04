-- Permite fijar a mano lo que va a costar el transporte del mes, en vez de deducirlo del
-- calendario.
--
-- El cálculo por días sirve mientras haya una rutina que proyectar. Cuando no la hay —un mes sin
-- empleo, unas vacaciones, una incapacidad— lo que se sabe no es cuántos pasajes se van a gastar
-- sino cuánto se va a poner en la tarjeta, y forzar a describirlo como días de oficina obliga a
-- inventar una rutina para que salga la cifra correcta.
--
-- Nulo significa que manda el calendario, que es el comportamiento de siempre.
ALTER TABLE transport_configs
    ADD COLUMN presupuesto_manual numeric(12,2);

ALTER TABLE transport_configs
    ADD CONSTRAINT ck_transport_configs_presupuesto
        CHECK (presupuesto_manual IS NULL OR presupuesto_manual >= 0);
