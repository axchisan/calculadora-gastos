-- Plan de pagos mes a mes de una deuda.
--
-- Una tarjeta de crédito no cobra lo mismo cada mes: el mínimo baja cuando terminan las cuotas
-- de un avance o de una compra diferida. Con una sola cuota fija el plan del sueldo repetía el
-- mínimo más alto hasta saldar la deuda. Si una deuda tiene estas cuotas, se usan en lugar de
-- su cuota mensual.
CREATE TABLE debt_schedule (
    id          uuid          PRIMARY KEY,
    debt_id     uuid          NOT NULL REFERENCES debts (id) ON DELETE CASCADE,
    fecha       date          NOT NULL,
    monto       numeric(14,2) NOT NULL,
    created_at  timestamptz   NOT NULL DEFAULT now(),
    CONSTRAINT ck_debt_schedule_monto CHECK (monto > 0)
);

CREATE UNIQUE INDEX ux_debt_schedule ON debt_schedule (debt_id, fecha);
