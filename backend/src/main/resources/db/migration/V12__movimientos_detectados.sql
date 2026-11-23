-- Registro automático, fase A: la bandeja de movimientos detectados.
--
-- Lo que llega de fuera (avisos por correo o SMS, líneas del extracto en PDF) se guarda aquí y
-- espera a que el usuario lo acepte, lo descarte o lo marque como ya registrado. Nunca se crea
-- un gasto o un ingreso sin que él lo vea.

-- Reglas del usuario: qué hacer con una contraparte conocida. Viven en la base y no en el
-- código porque nombran personas y cuentas reales.
CREATE TABLE detection_rules (
    id                   uuid         PRIMARY KEY,
    user_id              uuid         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    campo                varchar(12)  NOT NULL,
    valor                varchar(120) NOT NULL,
    accion               varchar(12)  NOT NULL,
    destino              varchar(10),
    categoria            varchar(30),
    nombre               varchar(120),
    created_at           timestamptz  NOT NULL,
    CONSTRAINT ck_detection_rules_campo CHECK (campo IN ('REFERENCIA', 'CONTRAPARTE')),
    CONSTRAINT ck_detection_rules_accion CHECK (accion IN ('DESCARTAR', 'SUGERIR')),
    CONSTRAINT ck_detection_rules_destino
        CHECK (destino IS NULL OR destino IN ('GASTO', 'COMPRA', 'INGRESO', 'ABONO'))
);

CREATE UNIQUE INDEX ux_detection_rules ON detection_rules (user_id, campo, lower(valor));

CREATE TABLE detected_movements (
    id                   uuid          PRIMARY KEY,
    user_id              uuid          NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    origen               varchar(12)   NOT NULL,
    banco                varchar(20)   NOT NULL,
    clase                varchar(30),
    monto                numeric(14,2),
    entra                boolean,
    fecha                date,
    hora                 time,
    cuenta               varchar(20),
    contraparte          varchar(200),
    referencia           varchar(100),
    -- El aviso o la línea tal como llegó, para reprocesarlo si cambia una plantilla.
    texto                text          NOT NULL,
    -- Evita guardar dos veces el mismo aviso o la misma línea del extracto.
    huella               varchar(64)   NOT NULL,
    estado               varchar(16)   NOT NULL,
    motivo               varchar(200),
    duplicado_de         uuid          REFERENCES detected_movements (id) ON DELETE SET NULL,
    coincide_tipo        varchar(10),
    coincide_id          uuid,
    regla_id             uuid          REFERENCES detection_rules (id) ON DELETE SET NULL,
    sugerencia_destino   varchar(10),
    sugerencia_categoria varchar(30),
    sugerencia_nombre    varchar(120),
    created_at           timestamptz   NOT NULL,
    resuelto_at          timestamptz,
    CONSTRAINT ck_detected_origen CHECK (origen IN ('CORREO', 'SMS', 'PDF', 'NOTIFICACION')),
    CONSTRAINT ck_detected_estado CHECK (estado IN
        ('PENDIENTE', 'ACEPTADO', 'DESCARTADO', 'YA_REGISTRADO', 'DUPLICADO', 'NO_RECONOCIDO')),
    CONSTRAINT ck_detected_monto CHECK (monto IS NULL OR monto > 0)
);

CREATE UNIQUE INDEX ux_detected_huella ON detected_movements (user_id, huella);
CREATE INDEX ix_detected_estado ON detected_movements (user_id, estado, fecha DESC);
CREATE INDEX ix_detected_cruce ON detected_movements (user_id, banco, monto, fecha);
