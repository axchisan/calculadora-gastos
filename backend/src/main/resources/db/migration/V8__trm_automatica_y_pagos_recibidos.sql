-- La TRM deja de teclearse: se toma cada día de la publicación oficial de la Superintendencia
-- Financiera (datos.gov.co). Quien prefiera fijarla a mano —por ejemplo, con la tasa que de
-- verdad aplica quien le paga— la desactiva.
ALTER TABLE income_sources
    ADD COLUMN trm_automatica boolean NOT NULL DEFAULT true;

-- Lo que de verdad llegó en cada pago. La proyección es una estimación con la TRM del día; esto es
-- el dato real, y de ahí sale la tasa que efectivamente se aplicó.
CREATE TABLE income_payments (
    id             uuid PRIMARY KEY,
    source_id      uuid          NOT NULL REFERENCES income_sources (id) ON DELETE CASCADE,
    mes_de_pago    varchar(7)    NOT NULL,
    monto_original numeric(12,2) NOT NULL,
    monto_pesos    numeric(14,2) NOT NULL,
    fecha          date          NOT NULL,
    created_at     timestamptz   NOT NULL DEFAULT now(),
    CONSTRAINT uq_income_payments_mes UNIQUE (source_id, mes_de_pago),
    CONSTRAINT ck_income_payments_montos CHECK (monto_original > 0 AND monto_pesos > 0),
    CONSTRAINT ck_income_payments_mes CHECK (mes_de_pago ~ '^[0-9]{4}-[0-9]{2}$')
);
