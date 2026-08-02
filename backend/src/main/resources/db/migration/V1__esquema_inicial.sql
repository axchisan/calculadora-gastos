-- Esquema inicial de la calculadora de gastos.
--
-- Convenciones:
--   · Dinero en numeric(14,2); nunca punto flotante.
--   · Identificadores UUID v7 generados en la aplicación (ordenables por tiempo).
--   · Fechas de negocio en date; auditoría en timestamptz.
--   · Los enumerados se modelan con varchar + CHECK, más fáciles de evolucionar que los
--     tipos enum nativos de PostgreSQL, que requieren ALTER TYPE para añadir valores.

-- ---------------------------------------------------------------------------
-- Usuarios y sesiones
-- ---------------------------------------------------------------------------

CREATE TABLE users (
    id            uuid PRIMARY KEY,
    email         varchar(255) NOT NULL,
    password_hash varchar(72)  NOT NULL,
    nombre        varchar(120) NOT NULL,
    moneda        varchar(3)   NOT NULL DEFAULT 'COP',
    zona_horaria  varchar(64)  NOT NULL DEFAULT 'America/Bogota',
    activo        boolean      NOT NULL DEFAULT true,
    created_at    timestamptz  NOT NULL DEFAULT now(),
    updated_at    timestamptz  NOT NULL DEFAULT now()
);

-- El correo se normaliza a minúsculas antes de persistir; el índice único sobre la
-- expresión evita que dos cuentas difieran solo en mayúsculas.
CREATE UNIQUE INDEX ux_users_email ON users (lower(email));

CREATE TABLE refresh_tokens (
    id          uuid PRIMARY KEY,
    user_id     uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    -- SHA-256 en hexadecimal: siempre 64 caracteres. Se usa varchar y no char porque char
    -- rellena con espacios a la derecha, lo que complica las comparaciones.
    token_hash  varchar(64) NOT NULL,
    -- Agrupa los tokens nacidos de una misma sesión. Si se reutiliza un token ya
    -- consumido, se revoca la familia completa: indica que fue robado.
    familia     uuid        NOT NULL,
    expires_at  timestamptz NOT NULL,
    revoked_at  timestamptz,
    used_at     timestamptz,
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX ux_refresh_tokens_hash ON refresh_tokens (token_hash);
CREATE INDEX ix_refresh_tokens_user ON refresh_tokens (user_id);
CREATE INDEX ix_refresh_tokens_familia ON refresh_tokens (familia);

-- ---------------------------------------------------------------------------
-- Plantillas de gastos fijos
-- ---------------------------------------------------------------------------

CREATE TABLE expense_templates (
    id              uuid PRIMARY KEY,
    user_id         uuid          NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    nombre          varchar(120)  NOT NULL,
    categoria       varchar(20)   NOT NULL,
    monto_default   numeric(14,2) NOT NULL DEFAULT 0,
    dia_vencimiento smallint,
    activo          boolean       NOT NULL DEFAULT true,
    orden           smallint      NOT NULL DEFAULT 0,
    created_at      timestamptz   NOT NULL DEFAULT now(),
    updated_at      timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT ck_expense_templates_categoria CHECK (categoria IN (
        'VIVIENDA', 'ALIMENTACION', 'TRANSPORTE', 'SERVICIOS', 'SUSCRIPCIONES',
        'SALUD', 'EDUCACION', 'DEPORTE', 'HERRAMIENTAS', 'DEUDA', 'AHORRO', 'OTRO')),
    CONSTRAINT ck_expense_templates_monto CHECK (monto_default >= 0),
    CONSTRAINT ck_expense_templates_dia CHECK (
        dia_vencimiento IS NULL OR dia_vencimiento BETWEEN 1 AND 31)
);

CREATE INDEX ix_expense_templates_user ON expense_templates (user_id, activo);

-- ---------------------------------------------------------------------------
-- Mes presupuestal
-- ---------------------------------------------------------------------------

CREATE TABLE budget_months (
    id           uuid PRIMARY KEY,
    user_id      uuid          NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    anio         smallint      NOT NULL,
    mes          smallint      NOT NULL,
    ingreso_base numeric(14,2) NOT NULL DEFAULT 0,
    cerrado      boolean       NOT NULL DEFAULT false,
    notas        text,
    created_at   timestamptz   NOT NULL DEFAULT now(),
    updated_at   timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT ck_budget_months_mes CHECK (mes BETWEEN 1 AND 12),
    CONSTRAINT ck_budget_months_anio CHECK (anio BETWEEN 2000 AND 2100),
    CONSTRAINT ck_budget_months_ingreso CHECK (ingreso_base >= 0),
    CONSTRAINT ux_budget_months_periodo UNIQUE (user_id, anio, mes)
);

-- Las gráficas recorren los meses del usuario en orden cronológico inverso.
CREATE INDEX ix_budget_months_cronologico ON budget_months (user_id, anio DESC, mes DESC);

CREATE TABLE incomes (
    id              uuid PRIMARY KEY,
    budget_month_id uuid          NOT NULL REFERENCES budget_months (id) ON DELETE CASCADE,
    concepto        varchar(120)  NOT NULL,
    monto           numeric(14,2) NOT NULL,
    fecha           date          NOT NULL,
    recibido        boolean       NOT NULL DEFAULT false,
    created_at      timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT ck_incomes_monto CHECK (monto > 0)
);

CREATE INDEX ix_incomes_mes ON incomes (budget_month_id);

-- ---------------------------------------------------------------------------
-- Gastos del mes
-- ---------------------------------------------------------------------------

CREATE TABLE expenses (
    id              uuid PRIMARY KEY,
    budget_month_id uuid          NOT NULL REFERENCES budget_months (id) ON DELETE CASCADE,
    -- Si se borra la plantilla, el gasto histórico se conserva sin vínculo.
    template_id     uuid          REFERENCES expense_templates (id) ON DELETE SET NULL,
    nombre          varchar(120)  NOT NULL,
    categoria       varchar(20)   NOT NULL,
    monto           numeric(14,2) NOT NULL DEFAULT 0,
    monto_pagado    numeric(14,2) NOT NULL DEFAULT 0,
    estado          varchar(10)   NOT NULL DEFAULT 'PENDIENTE',
    fecha_pago      date,
    dia_vencimiento smallint,
    -- Distingue los gastos que genera el sistema (transporte, abonos a deudas), que no se
    -- editan directamente sino desde su propio módulo.
    origen          varchar(12)   NOT NULL DEFAULT 'MANUAL',
    notas           text,
    orden           smallint      NOT NULL DEFAULT 0,
    created_at      timestamptz   NOT NULL DEFAULT now(),
    updated_at      timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT ck_expenses_categoria CHECK (categoria IN (
        'VIVIENDA', 'ALIMENTACION', 'TRANSPORTE', 'SERVICIOS', 'SUSCRIPCIONES',
        'SALUD', 'EDUCACION', 'DEPORTE', 'HERRAMIENTAS', 'DEUDA', 'AHORRO', 'OTRO')),
    CONSTRAINT ck_expenses_estado CHECK (estado IN ('PENDIENTE', 'PARCIAL', 'PAGADO')),
    CONSTRAINT ck_expenses_origen CHECK (origen IN ('MANUAL', 'PLANTILLA', 'TRANSPORTE', 'DEUDA')),
    CONSTRAINT ck_expenses_monto CHECK (monto >= 0),
    CONSTRAINT ck_expenses_pagado CHECK (monto_pagado >= 0 AND monto_pagado <= monto),
    -- El estado debe ser coherente con lo efectivamente abonado.
    CONSTRAINT ck_expenses_estado_coherente CHECK (
        (estado = 'PENDIENTE' AND monto_pagado = 0)
        OR (estado = 'PAGADO' AND monto_pagado = monto)
        OR (estado = 'PARCIAL' AND monto_pagado > 0 AND monto_pagado < monto))
);

CREATE INDEX ix_expenses_mes ON expenses (budget_month_id);
CREATE INDEX ix_expenses_pendientes ON expenses (budget_month_id, estado)
    WHERE estado <> 'PAGADO';

-- ---------------------------------------------------------------------------
-- Deudas externas
-- ---------------------------------------------------------------------------

CREATE TABLE debts (
    id                   uuid PRIMARY KEY,
    user_id              uuid          NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    acreedor             varchar(120)  NOT NULL,
    descripcion          text,
    tipo                 varchar(20)   NOT NULL,
    monto_original       numeric(14,2) NOT NULL,
    saldo                numeric(14,2) NOT NULL,
    tasa_interes_mensual numeric(6,4),
    cuota_sugerida       numeric(14,2),
    fecha_inicio         date          NOT NULL,
    fecha_limite         date,
    activa               boolean       NOT NULL DEFAULT true,
    created_at           timestamptz   NOT NULL DEFAULT now(),
    updated_at           timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT ck_debts_tipo CHECK (tipo IN (
        'TARJETA_CREDITO', 'PRESTAMO_BANCARIO', 'FAMILIAR', 'AMIGO', 'OTRO')),
    CONSTRAINT ck_debts_monto CHECK (monto_original > 0),
    CONSTRAINT ck_debts_saldo CHECK (saldo >= 0),
    CONSTRAINT ck_debts_tasa CHECK (tasa_interes_mensual IS NULL OR tasa_interes_mensual >= 0),
    CONSTRAINT ck_debts_fechas CHECK (fecha_limite IS NULL OR fecha_limite >= fecha_inicio)
);

CREATE INDEX ix_debts_user ON debts (user_id, activa);

CREATE TABLE debt_payments (
    id              uuid PRIMARY KEY,
    debt_id         uuid          NOT NULL REFERENCES debts (id) ON DELETE CASCADE,
    -- Un abono puede registrarse sin vincularlo a un mes concreto.
    budget_month_id uuid          REFERENCES budget_months (id) ON DELETE SET NULL,
    monto           numeric(14,2) NOT NULL,
    fecha           date          NOT NULL,
    nota            text,
    created_at      timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT ck_debt_payments_monto CHECK (monto > 0)
);

CREATE INDEX ix_debt_payments_deuda ON debt_payments (debt_id, fecha DESC);
CREATE INDEX ix_debt_payments_mes ON debt_payments (budget_month_id);

-- ---------------------------------------------------------------------------
-- Ahorro y distribución del excedente
-- ---------------------------------------------------------------------------

CREATE TABLE savings_goals (
    id               uuid PRIMARY KEY,
    user_id          uuid          NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    nombre           varchar(120)  NOT NULL,
    tipo_asignacion  varchar(22)   NOT NULL,
    valor            numeric(14,2) NOT NULL,
    meta_monto       numeric(14,2),
    saldo_acumulado  numeric(14,2) NOT NULL DEFAULT 0,
    color            varchar(9),
    prioridad        smallint      NOT NULL DEFAULT 0,
    activa           boolean       NOT NULL DEFAULT true,
    created_at       timestamptz   NOT NULL DEFAULT now(),
    updated_at       timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT ck_savings_goals_tipo CHECK (tipo_asignacion IN (
        'PORCENTAJE_INGRESO', 'MONTO_FIJO', 'PORCENTAJE_SOBRANTE')),
    CONSTRAINT ck_savings_goals_valor CHECK (valor >= 0),
    -- Los tipos porcentuales no admiten valores por encima de 100.
    CONSTRAINT ck_savings_goals_porcentaje CHECK (
        tipo_asignacion = 'MONTO_FIJO' OR valor <= 100),
    CONSTRAINT ck_savings_goals_meta CHECK (meta_monto IS NULL OR meta_monto > 0)
);

CREATE INDEX ix_savings_goals_user ON savings_goals (user_id, activa, prioridad);

CREATE TABLE savings_movements (
    id              uuid PRIMARY KEY,
    savings_goal_id uuid          NOT NULL REFERENCES savings_goals (id) ON DELETE CASCADE,
    budget_month_id uuid          REFERENCES budget_months (id) ON DELETE SET NULL,
    tipo            varchar(7)    NOT NULL,
    monto           numeric(14,2) NOT NULL,
    fecha           date          NOT NULL,
    nota            text,
    created_at      timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT ck_savings_movements_tipo CHECK (tipo IN ('APORTE', 'RETIRO')),
    CONSTRAINT ck_savings_movements_monto CHECK (monto > 0)
);

CREATE INDEX ix_savings_movements_meta ON savings_movements (savings_goal_id, fecha DESC);
CREATE INDEX ix_savings_movements_mes ON savings_movements (budget_month_id);

-- ---------------------------------------------------------------------------
-- Transporte
-- ---------------------------------------------------------------------------

CREATE TABLE transport_configs (
    id                        uuid PRIMARY KEY,
    budget_month_id           uuid          NOT NULL REFERENCES budget_months (id)
                                            ON DELETE CASCADE,
    valor_pasaje              numeric(10,2) NOT NULL,
    pasajes_dia_oficina       smallint      NOT NULL DEFAULT 2,
    pasajes_extra_karate      smallint      NOT NULL DEFAULT 1,
    pasajes_karate_desde_casa smallint      NOT NULL DEFAULT 2,
    -- ISO-8601: 1 = lunes … 7 = domingo.
    dias_laborales            smallint[]    NOT NULL DEFAULT '{1,2,3,4,5}',
    dias_karate               smallint[]    NOT NULL DEFAULT '{2,4}',
    dias_remotos_por_semana   smallint      NOT NULL DEFAULT 1,
    created_at                timestamptz   NOT NULL DEFAULT now(),
    updated_at                timestamptz   NOT NULL DEFAULT now(),

    CONSTRAINT ux_transport_configs_mes UNIQUE (budget_month_id),
    CONSTRAINT ck_transport_configs_pasaje CHECK (valor_pasaje >= 0),
    CONSTRAINT ck_transport_configs_pasajes CHECK (
        pasajes_dia_oficina >= 0 AND pasajes_extra_karate >= 0
        AND pasajes_karate_desde_casa >= 0),
    CONSTRAINT ck_transport_configs_remotos CHECK (dias_remotos_por_semana BETWEEN 0 AND 7)
);

CREATE TABLE transport_days (
    id              uuid PRIMARY KEY,
    budget_month_id uuid        NOT NULL REFERENCES budget_months (id) ON DELETE CASCADE,
    fecha           date        NOT NULL,
    tipo            varchar(14) NOT NULL,
    hay_karate      boolean     NOT NULL DEFAULT false,
    pasajes         smallint    NOT NULL DEFAULT 0,
    -- Protege el valor de los recálculos automáticos cuando el usuario lo fija a mano.
    override_manual boolean     NOT NULL DEFAULT false,
    -- El día ya transcurrió y se confirmó lo realmente gastado.
    confirmado      boolean     NOT NULL DEFAULT false,
    nombre_festivo  varchar(120),
    nota            text,

    CONSTRAINT ck_transport_days_tipo CHECK (tipo IN (
        'OFICINA', 'REMOTO', 'FESTIVO', 'FIN_DE_SEMANA', 'VACACIONES', 'AUSENTE')),
    CONSTRAINT ck_transport_days_pasajes CHECK (pasajes >= 0),
    CONSTRAINT ux_transport_days_fecha UNIQUE (budget_month_id, fecha)
);

CREATE INDEX ix_transport_days_mes ON transport_days (budget_month_id, fecha);

-- ---------------------------------------------------------------------------
-- Festivos
-- ---------------------------------------------------------------------------

-- Los festivos se calculan de forma determinista en la aplicación (Ley 51 de 1983); esta
-- tabla los materializa para poder consultarlos con SQL y admitir excepciones puntuales.
CREATE TABLE holidays (
    fecha  date         NOT NULL,
    nombre varchar(120) NOT NULL,
    tipo   varchar(11)  NOT NULL,

    CONSTRAINT pk_holidays PRIMARY KEY (fecha, nombre),
    CONSTRAINT ck_holidays_tipo CHECK (tipo IN ('FIJO', 'TRASLADADO', 'PASCUA'))
);

CREATE INDEX ix_holidays_fecha ON holidays (fecha);
