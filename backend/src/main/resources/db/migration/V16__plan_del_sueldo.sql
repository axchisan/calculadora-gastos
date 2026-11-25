-- «Mi plan»: cuánto sobra del sueldo cada mes y cuándo se alcanza una meta.
--
-- El gasto del día a día (comida, antojos, transporte) no es un gasto fijo, pero sin él lo que
-- «sobra» sería una ilusión. La app lo estima con lo comprado en los últimos meses; aquí se
-- guarda la cifra si el usuario prefiere poner la suya.
ALTER TABLE users ADD COLUMN plan_gasto_diario numeric(14,2);
