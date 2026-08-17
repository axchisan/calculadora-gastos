-- Cómo se reconoce una tarjeta en las notificaciones de pago del teléfono.
--
-- Cuando se paga acercando el móvil, Google Wallet publica una notificación con el apodo que
-- el usuario le puso a la tarjeta dentro de la billetera («crédito física»), y el banco publica
-- otra con los cuatro últimos dígitos («terminada en 2355»). Ninguno de los dos es el nombre
-- que la tarjeta tiene en esta aplicación.
--
-- Esta tabla es la traducción entre ambos mundos, y es lo que permite saber si una compra
-- capturada salió del dinero de hoy o se va al corte del mes que viene.
--
-- Va en tabla aparte y no en columnas de `cards` porque la relación es de varios a uno: Nu
-- entrega una tarjeta virtual y una física sobre la misma línea de crédito, con números
-- distintos y apodos distintos, pero un único corte.

CREATE TABLE card_aliases (
    id         uuid PRIMARY KEY,
    card_id    uuid        NOT NULL REFERENCES cards (id) ON DELETE CASCADE,

    -- El apodo tal y como aparece en la notificación de Google Wallet. Se guarda además
    -- normalizado —en minúsculas y sin tildes— porque el usuario escribió «crédito física»
    -- con tilde y «credito digital» sin ella, y comparar el texto crudo fallaría.
    alias      varchar(60),
    alias_norm varchar(60),

    -- Los cuatro últimos dígitos, que publica el banco. Es el identificador fiable: no depende
    -- de cómo se haya escrito nada.
    --
    -- Se usa varchar y no char aunque la longitud sea siempre la misma: char rellena con
    -- espacios a la derecha, lo que estropea las comparaciones, y además Hibernate lo valida
    -- como tipos distintos y se niega a arrancar.
    ultimos4   varchar(4),

    created_at timestamptz NOT NULL DEFAULT now(),

    -- Un alias que no dice nada no sirve para reconocer.
    CONSTRAINT ck_card_aliases_algo CHECK (alias IS NOT NULL OR ultimos4 IS NOT NULL),
    CONSTRAINT ck_card_aliases_ultimos4 CHECK (ultimos4 IS NULL OR ultimos4 ~ '^[0-9]{4}$')
);

CREATE INDEX ix_card_aliases_card ON card_aliases (card_id);

-- No se repite el mismo apodo dentro de una tarjeta. Que dos tarjetas distintas del mismo
-- usuario no compartan apodo se comprueba en el servicio, donde se conoce el usuario: aquí no
-- hay columna que lo identifique y añadirla solo para esto duplicaría el dato.
CREATE UNIQUE INDEX ux_card_aliases_norm ON card_aliases (card_id, alias_norm)
    WHERE alias_norm IS NOT NULL;
CREATE UNIQUE INDEX ux_card_aliases_ultimos4 ON card_aliases (card_id, ultimos4)
    WHERE ultimos4 IS NOT NULL;
