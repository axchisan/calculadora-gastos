-- Dos piezas que faltaban para llevar las cuentas al día con varios bancos y un sueldo en dólares.
--
-- 1. accounts: el saldo real de cada sitio donde hay dinero (bancos, billeteras, efectivo).
--    El disponible del mes sale de lo que se registra; estas cifras salen de mirar el banco.
--    Ponerlas una al lado de la otra es lo que permite ver si falta algo por apuntar.
--
-- 2. income_sources: un ingreso recurrente en otra moneda, con todo lo que hace falta para
--    estimar cuántos pesos llegan y cuándo: la TRM de referencia, las comisiones del medio de
--    cobro y la ventana de días hábiles en la que suele llegar el pago.

CREATE TABLE accounts (
    id         uuid PRIMARY KEY,
    user_id    uuid          NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    nombre     varchar(60)   NOT NULL,
    tipo       varchar(12)   NOT NULL,
    saldo      numeric(14,2) NOT NULL DEFAULT 0,
    saldo_al   date          NOT NULL DEFAULT CURRENT_DATE,
    activa     boolean       NOT NULL DEFAULT true,
    orden      smallint      NOT NULL DEFAULT 0,
    created_at timestamptz   NOT NULL DEFAULT now(),
    updated_at timestamptz   NOT NULL DEFAULT now(),
    CONSTRAINT ck_accounts_tipo CHECK (tipo IN ('BANCO', 'BILLETERA', 'EFECTIVO'))
);

CREATE INDEX ix_accounts_usuario ON accounts (user_id, activa, orden);

CREATE TABLE income_sources (
    id                          uuid PRIMARY KEY,
    user_id                     uuid          NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    nombre                      varchar(80)   NOT NULL,
    moneda                      varchar(3)    NOT NULL DEFAULT 'USD',
    monto_mensual               numeric(12,2) NOT NULL,
    fecha_inicio                date          NOT NULL,
    fecha_fin                   date,
    medio                       varchar(16)   NOT NULL DEFAULT 'TRANSFERENCIA',
    cuenta_destino              varchar(60),
    dias_habiles_pago           smallint      NOT NULL DEFAULT 5,
    dias_tolerancia             smallint      NOT NULL DEFAULT 2,
    trm_referencia              numeric(10,2) NOT NULL,
    trm_fecha                   date          NOT NULL,
    comision_porcentaje         numeric(5,2)  NOT NULL DEFAULT 0,
    comision_fija               numeric(8,2)  NOT NULL DEFAULT 0,
    descuento_cambio_porcentaje numeric(5,2)  NOT NULL DEFAULT 0,
    costo_retiro                numeric(10,2) NOT NULL DEFAULT 0,
    activo                      boolean       NOT NULL DEFAULT true,
    notas                       text,
    created_at                  timestamptz   NOT NULL DEFAULT now(),
    updated_at                  timestamptz   NOT NULL DEFAULT now(),
    CONSTRAINT ck_income_sources_monto CHECK (monto_mensual > 0),
    CONSTRAINT ck_income_sources_medio CHECK (medio IN ('TRANSFERENCIA', 'PAYPAL')),
    CONSTRAINT ck_income_sources_dias CHECK (dias_habiles_pago BETWEEN 1 AND 20
        AND dias_tolerancia BETWEEN 0 AND 10),
    CONSTRAINT ck_income_sources_trm CHECK (trm_referencia > 0),
    CONSTRAINT ck_income_sources_costos CHECK (comision_porcentaje >= 0 AND comision_fija >= 0
        AND descuento_cambio_porcentaje >= 0 AND costo_retiro >= 0),
    CONSTRAINT ck_income_sources_fechas CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio)
);

CREATE INDEX ix_income_sources_usuario ON income_sources (user_id, activo);
