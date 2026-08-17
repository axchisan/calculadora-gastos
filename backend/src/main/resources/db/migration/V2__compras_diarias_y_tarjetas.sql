-- Compras del día a día y tarjetas.
--
-- Hasta ahora todo gasto vivía en `expenses`, pensada para los compromisos grandes del mes:
-- arriendo, celular, karate. Mezclar ahí un chocorramo de 3.600 hacía ilegible la lista y
-- desvirtuaba la distribución por categorías de las gráficas.
--
-- Las compras diarias son otra cosa y se modelan aparte porque su ciclo de vida es distinto:
-- una compra ya ocurrió y ya se pagó en el momento en que se hizo. No tiene estado pendiente
-- ni abonos parciales; lo único que varía es de dónde salió el dinero.
--
-- Y ahí está lo interesante: si se pagó con crédito, el dinero NO sale del mes en que se
-- compró. Sale en el mes en que vence el corte de la tarjeta.

-- ---------------------------------------------------------------------------
-- Categorías nuevas
-- ---------------------------------------------------------------------------
-- El día a día necesita más grano que los gastos fijos: un perfume, una comisión de cajero y
-- una gaseosa no son «OTRO» los tres. Los enumerados se modelan con varchar + CHECK
-- precisamente para poder ampliarlos sin ALTER TYPE.

ALTER TABLE expenses DROP CONSTRAINT ck_expenses_categoria;
ALTER TABLE expense_templates DROP CONSTRAINT ck_expense_templates_categoria;

-- varchar(20) se queda corto para CUIDADO_PERSONAL.
ALTER TABLE expenses ALTER COLUMN categoria TYPE varchar(24);
ALTER TABLE expense_templates ALTER COLUMN categoria TYPE varchar(24);

ALTER TABLE expenses ADD CONSTRAINT ck_expenses_categoria CHECK (categoria IN (
    'VIVIENDA', 'ALIMENTACION', 'TRANSPORTE', 'SERVICIOS', 'SUSCRIPCIONES',
    'SALUD', 'EDUCACION', 'DEPORTE', 'HERRAMIENTAS', 'DEUDA', 'AHORRO',
    'ANTOJOS', 'CUIDADO_PERSONAL', 'COMISIONES', 'OCIO', 'ROPA', 'HOGAR', 'OTRO'));

ALTER TABLE expense_templates ADD CONSTRAINT ck_expense_templates_categoria CHECK (categoria IN (
    'VIVIENDA', 'ALIMENTACION', 'TRANSPORTE', 'SERVICIOS', 'SUSCRIPCIONES',
    'SALUD', 'EDUCACION', 'DEPORTE', 'HERRAMIENTAS', 'DEUDA', 'AHORRO',
    'ANTOJOS', 'CUIDADO_PERSONAL', 'COMISIONES', 'OCIO', 'ROPA', 'HOGAR', 'OTRO'));

-- ---------------------------------------------------------------------------
-- Tarjetas
-- ---------------------------------------------------------------------------

CREATE TABLE cards (
    id         uuid PRIMARY KEY,
    user_id    uuid         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    nombre     varchar(60)  NOT NULL,
    tipo       varchar(10)  NOT NULL,
    -- Solo para crédito. El corte cierra el periodo de consumo y el pago vence el mes
    -- siguiente: una compra del 14 con corte el 15 se paga el 4 del mes siguiente; una del 16
    -- entra al corte siguiente y se paga un mes más tarde.
    dia_corte  smallint,
    dia_pago   smallint,
    -- Se dibuja en la interfaz para distinguir las tarjetas de un vistazo.
    color      varchar(9),
    activa     boolean      NOT NULL DEFAULT true,
    orden      smallint     NOT NULL DEFAULT 0,
    created_at timestamptz  NOT NULL DEFAULT now(),
    updated_at timestamptz  NOT NULL DEFAULT now(),

    CONSTRAINT ck_cards_tipo CHECK (tipo IN ('DEBITO', 'CREDITO')),
    CONSTRAINT ck_cards_dia_corte CHECK (dia_corte IS NULL OR dia_corte BETWEEN 1 AND 28),
    CONSTRAINT ck_cards_dia_pago CHECK (dia_pago IS NULL OR dia_pago BETWEEN 1 AND 28),
    -- Una tarjeta de crédito sin ciclo no permitiría saber en qué mes se paga lo que se
    -- compra con ella, que es justamente lo que se quiere calcular.
    CONSTRAINT ck_cards_ciclo CHECK (
        tipo <> 'CREDITO' OR (dia_corte IS NOT NULL AND dia_pago IS NOT NULL))
);

CREATE INDEX ix_cards_user ON cards (user_id, activa);

-- ---------------------------------------------------------------------------
-- Compras del día a día
-- ---------------------------------------------------------------------------

CREATE TABLE purchases (
    id              uuid PRIMARY KEY,
    -- El mes en que se hizo la compra, no en el que se paga. Son distintos con crédito, y
    -- para saber en qué se va el dinero importa cuándo se gastó.
    budget_month_id uuid          NOT NULL REFERENCES budget_months (id) ON DELETE CASCADE,
    fecha           date          NOT NULL,
    descripcion     varchar(120)  NOT NULL,
    categoria       varchar(24)   NOT NULL,
    monto           numeric(14,2) NOT NULL,
    medio           varchar(10)   NOT NULL DEFAULT 'EFECTIVO',
    -- Si se borra la tarjeta, la compra histórica se conserva sin vínculo.
    card_id         uuid          REFERENCES cards (id) ON DELETE SET NULL,

    -- Mes en que el dinero sale de verdad. Con efectivo y débito coincide con el de la
    -- compra; con crédito lo determina el corte de la tarjeta.
    --
    -- Se guarda en lugar de recalcularse al vuelo por dos razones: permite agrupar y sumar en
    -- una sola consulta, y sobre todo congela el resultado. Si algún día cambia el día de
    -- corte de la tarjeta, las compras ya hechas conservan el mes en el que realmente se
    -- pagaron, en vez de reescribir el pasado.
    pago_anio       smallint      NOT NULL,
    pago_mes        smallint      NOT NULL,

    -- Solo tiene sentido con crédito: el corte se paga entero cuando vence. Con efectivo o
    -- débito el dinero ya salió, así que nace en true.
    pagado          boolean       NOT NULL DEFAULT true,

    -- De dónde salió el registro. NOTIFICACION queda reservado para las compras que la
    -- aplicación de Android capture de las notificaciones de pago del teléfono.
    origen          varchar(12)   NOT NULL DEFAULT 'MANUAL',
    nota            varchar(200),
    created_at      timestamptz   NOT NULL DEFAULT now(),
    updated_at      timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT ck_purchases_monto CHECK (monto > 0),
    CONSTRAINT ck_purchases_medio CHECK (medio IN ('EFECTIVO', 'DEBITO', 'CREDITO')),
    CONSTRAINT ck_purchases_origen CHECK (origen IN ('MANUAL', 'NOTIFICACION')),
    CONSTRAINT ck_purchases_categoria CHECK (categoria IN (
        'VIVIENDA', 'ALIMENTACION', 'TRANSPORTE', 'SERVICIOS', 'SUSCRIPCIONES',
        'SALUD', 'EDUCACION', 'DEPORTE', 'HERRAMIENTAS', 'DEUDA', 'AHORRO',
        'ANTOJOS', 'CUIDADO_PERSONAL', 'COMISIONES', 'OCIO', 'ROPA', 'HOGAR', 'OTRO')),
    CONSTRAINT ck_purchases_pago_mes CHECK (pago_mes BETWEEN 1 AND 12),
    CONSTRAINT ck_purchases_pago_anio CHECK (pago_anio BETWEEN 2000 AND 2100),
    -- Una compra a crédito necesita saber con qué tarjeta se hizo para poder agruparla en su
    -- corte; sin tarjeta no habría forma de saber cuándo vence.
    CONSTRAINT ck_purchases_credito_con_tarjeta CHECK (medio <> 'CREDITO' OR card_id IS NOT NULL)
);

CREATE INDEX ix_purchases_mes ON purchases (budget_month_id, fecha DESC);

-- Para sumar el corte que vence en un mes dado hay que cruzar por usuario, no por mes de
-- compra: las compras que se pagan en octubre están repartidas entre agosto y septiembre.
CREATE INDEX ix_purchases_periodo_pago ON purchases (card_id, pago_anio, pago_mes)
    WHERE medio = 'CREDITO';
