-- Rediseño v2, fase 5: Movimientos.

-- ---------------------------------------------------------------------------
-- Ingresos: de dónde vino el dinero y una nota
-- ---------------------------------------------------------------------------
-- Un préstamo que entra no es dinero ganado, y en la lista de movimientos debe distinguirse a la
-- primera de un pago por un trabajo. El tipo permite marcarlo y darle su icono.
ALTER TABLE incomes
    ADD COLUMN tipo  varchar(12) NOT NULL DEFAULT 'OTRO',
    ADD COLUMN notas text,
    ADD CONSTRAINT ck_incomes_tipo CHECK (tipo IN (
        'TRABAJO', 'FAMILIA', 'PRESTAMO', 'INTERESES', 'SALDO', 'OTRO'));

-- Clasificación inicial de lo que ya existe, por las palabras habituales del concepto. Lo que no
-- encaja queda como OTRO y se corrige desde la app.
UPDATE incomes SET tipo = 'SALDO'
 WHERE concepto ILIKE 'saldo %';
UPDATE incomes SET tipo = 'PRESTAMO'
 WHERE tipo = 'OTRO'
   AND (concepto ILIKE '%préstamo%' OR concepto ILIKE '%prestamo%'
        OR concepto ILIKE '%avance%' OR concepto ILIKE '%desembolso%');
UPDATE incomes SET tipo = 'INTERESES'
 WHERE tipo = 'OTRO' AND concepto ILIKE '%intereses%';
UPDATE incomes SET tipo = 'TRABAJO'
 WHERE tipo = 'OTRO'
   AND (concepto ILIKE '%nómina%' OR concepto ILIKE '%nomina%' OR concepto ILIKE '%trabajo%'
        OR concepto ILIKE '%sueldo%' OR concepto ILIKE '%honorarios%');
-- Después de Trabajo: «trabajos que pagó alguien vía mamá» siguen siendo trabajo.
UPDATE incomes SET tipo = 'FAMILIA'
 WHERE tipo = 'OTRO'
   AND (concepto ILIKE '%mamá%' OR concepto ILIKE '%mama%' OR concepto ILIKE '%papá%'
        OR concepto ILIKE '%apoyo%');

-- ---------------------------------------------------------------------------
-- Categoría Mascota
-- ---------------------------------------------------------------------------
-- Comida, aseo y accesorios de la mascota acababan en Hogar u Otro.
ALTER TABLE expenses DROP CONSTRAINT ck_expenses_categoria;
ALTER TABLE expense_templates DROP CONSTRAINT ck_expense_templates_categoria;
ALTER TABLE purchases DROP CONSTRAINT ck_purchases_categoria;

ALTER TABLE expenses ADD CONSTRAINT ck_expenses_categoria CHECK (categoria IN (
    'VIVIENDA', 'ALIMENTACION', 'TRANSPORTE', 'SERVICIOS', 'SUSCRIPCIONES',
    'SALUD', 'EDUCACION', 'DEPORTE', 'HERRAMIENTAS', 'DEUDA', 'AHORRO',
    'ANTOJOS', 'CUIDADO_PERSONAL', 'COMISIONES', 'OCIO', 'ROPA', 'HOGAR', 'MASCOTA', 'OTRO'));

ALTER TABLE expense_templates ADD CONSTRAINT ck_expense_templates_categoria CHECK (categoria IN (
    'VIVIENDA', 'ALIMENTACION', 'TRANSPORTE', 'SERVICIOS', 'SUSCRIPCIONES',
    'SALUD', 'EDUCACION', 'DEPORTE', 'HERRAMIENTAS', 'DEUDA', 'AHORRO',
    'ANTOJOS', 'CUIDADO_PERSONAL', 'COMISIONES', 'OCIO', 'ROPA', 'HOGAR', 'MASCOTA', 'OTRO'));

ALTER TABLE purchases ADD CONSTRAINT ck_purchases_categoria CHECK (categoria IN (
    'VIVIENDA', 'ALIMENTACION', 'TRANSPORTE', 'SERVICIOS', 'SUSCRIPCIONES',
    'SALUD', 'EDUCACION', 'DEPORTE', 'HERRAMIENTAS', 'DEUDA', 'AHORRO',
    'ANTOJOS', 'CUIDADO_PERSONAL', 'COMISIONES', 'OCIO', 'ROPA', 'HOGAR', 'MASCOTA', 'OTRO'));
