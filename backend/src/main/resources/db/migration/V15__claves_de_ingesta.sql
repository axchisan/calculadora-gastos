-- Registro automático, fase C: avisos que llegan solos.
--
-- El teléfono (al recibir un SMS del banco) y el script de Gmail envían avisos sin la sesión
-- del usuario, que caduca. Cada uno usa una clave propia, que solo sirve para enviar avisos y
-- se puede revocar. Se guarda solo su huella SHA-256: la clave se muestra una vez al crearla.
CREATE TABLE ingest_keys (
    id            uuid         PRIMARY KEY,
    user_id       uuid         NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    nombre        varchar(40)  NOT NULL,
    huella        varchar(64)  NOT NULL,
    created_at    timestamptz  NOT NULL,
    usada_en      timestamptz,
    revocada_en   timestamptz
);

CREATE UNIQUE INDEX ux_ingest_keys_huella ON ingest_keys (huella);
CREATE INDEX ix_ingest_keys_usuario ON ingest_keys (user_id);
