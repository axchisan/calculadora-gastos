-- Créditos con plan de pagos.
--
-- Una deuda de `debts` es una cifra que se debe y se va abonando. Un crédito bancario es otra
-- cosa: tiene un cuadro de amortización cerrado, con una fecha y un reparto entre capital e
-- interés para cada cuota, y ese reparto es lo que hace que abonar de más ahorre dinero.
--
-- Al 76% efectivo anual, adelantar una cuota no ahorra «una cuota»: ahorra todos los intereses
-- que ese capital habría generado hasta el final. Sin el cuadro no hay forma de calcularlo, y
-- sin poder calcularlo la decisión de si conviene abonar se toma a ciegas.

CREATE TABLE credits (
    id                uuid PRIMARY KEY,
    user_id           uuid          NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    entidad           varchar(60)   NOT NULL,
    -- El número con el que el banco identifica la operación, para poder cotejar con el papel.
    numero_operacion  varchar(40),
    descripcion       varchar(120),
    monto_original    numeric(14,2) NOT NULL,
    -- Tasa efectiva anual, tal y como la publica el banco. La mensual se deriva de ella.
    tasa_ea           numeric(9,6),
    plazo_cuotas      smallint      NOT NULL,
    dia_pago          smallint,
    fecha_desembolso  date,
    fecha_vencimiento date,
    activo            boolean       NOT NULL DEFAULT true,
    created_at        timestamptz   NOT NULL DEFAULT now(),
    updated_at        timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT ck_credits_monto CHECK (monto_original > 0),
    CONSTRAINT ck_credits_plazo CHECK (plazo_cuotas > 0),
    CONSTRAINT ck_credits_tasa CHECK (tasa_ea IS NULL OR tasa_ea >= 0),
    CONSTRAINT ck_credits_dia_pago CHECK (dia_pago IS NULL OR dia_pago BETWEEN 1 AND 28)
);

CREATE INDEX ix_credits_user ON credits (user_id, activo);

-- Cada fila es una cuota del cuadro, con los mismos conceptos que imprime el banco. Se
-- conservan por separado y no como un único total porque la gracia está justamente en el
-- reparto: cuánto de la cuota mata deuda y cuánto se lo lleva el interés.
CREATE TABLE credit_installments (
    id            uuid PRIMARY KEY,
    credit_id     uuid          NOT NULL REFERENCES credits (id) ON DELETE CASCADE,
    numero        smallint      NOT NULL,
    fecha         date          NOT NULL,
    dias          smallint,
    -- Lo que se debe justo antes de pagar esta cuota.
    saldo_capital numeric(14,2) NOT NULL,
    capital       numeric(14,2) NOT NULL,
    interes       numeric(14,2) NOT NULL,
    mora          numeric(14,2) NOT NULL DEFAULT 0,
    -- Cargo fijo de la Ley Mipyme. Baja a mitad de plan, así que no se puede dar por constante.
    mipyme        numeric(14,2) NOT NULL DEFAULT 0,
    seguro        numeric(14,2) NOT NULL DEFAULT 0,
    otros         numeric(14,2) NOT NULL DEFAULT 0,
    valor_cuota   numeric(14,2) NOT NULL,

    pagada        boolean       NOT NULL DEFAULT false,
    fecha_pago    date,
    monto_pagado  numeric(14,2),

    created_at    timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT ux_credit_installments UNIQUE (credit_id, numero),
    CONSTRAINT ck_credit_installments_numero CHECK (numero > 0),
    CONSTRAINT ck_credit_installments_importes CHECK (
        capital >= 0 AND interes >= 0 AND mora >= 0
        AND mipyme >= 0 AND seguro >= 0 AND otros >= 0 AND valor_cuota >= 0)
);

CREATE INDEX ix_credit_installments_credito ON credit_installments (credit_id, numero);

-- Las cuotas que vencen en un mes se buscan por fecha para cruzarlas con el presupuesto.
CREATE INDEX ix_credit_installments_fecha ON credit_installments (credit_id, fecha)
    WHERE NOT pagada;
