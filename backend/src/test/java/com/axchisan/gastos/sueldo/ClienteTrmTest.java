package com.axchisan.gastos.sueldo;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;

import static org.assertj.core.api.Assertions.assertThat;

@DisplayName("Elegir la TRM vigente de la lista publicada")
class ClienteTrmTest {

    /** Respuesta real de datos.gov.co del 15 nov 2026: el viernes publicó la del fin de semana. */
    private static final String PUBLICADO = """
            [{"valor":"3316.7","unidad":"COP","vigenciadesde":"2026-11-14T00:00:00.000","vigenciahasta":"2026-11-17T00:00:00.000"},
             {"valor":"3301.91","unidad":"COP","vigenciadesde":"2026-11-13T00:00:00.000","vigenciahasta":"2026-11-13T00:00:00.000"},
             {"valor":"3297.07","unidad":"COP","vigenciadesde":"2026-11-11T00:00:00.000","vigenciahasta":"2026-11-12T00:00:00.000"}]
            """;

    private final ObjectMapper json = new ObjectMapper();

    @Test
    @DisplayName("Un domingo vale la tasa publicada el viernes para todo el fin de semana")
    void finDeSemana() throws Exception {
        var trm = ClienteTrm.elegir(json.readTree(PUBLICADO), LocalDate.of(2026, 11, 15));
        assertThat(trm).isPresent();
        assertThat(trm.get().valor()).isEqualByComparingTo("3316.7");
        assertThat(trm.get().vigenteHasta()).isEqualTo(LocalDate.of(2026, 11, 17));
    }

    @Test
    @DisplayName("Un día entre semana toma la suya")
    void entreSemana() throws Exception {
        var trm = ClienteTrm.elegir(json.readTree(PUBLICADO), LocalDate.of(2026, 11, 12));
        assertThat(trm.get().valor()).isEqualByComparingTo("3297.07");
    }

    @Test
    @DisplayName("Si la del día aún no se publica, se usa la más reciente anterior")
    void aunSinPublicar() throws Exception {
        var trm = ClienteTrm.elegir(json.readTree(PUBLICADO), LocalDate.of(2026, 11, 18));
        assertThat(trm.get().valor()).isEqualByComparingTo("3316.7");
    }

    @Test
    @DisplayName("Desactivado no consulta nada")
    void desactivado() {
        assertThat(new ClienteTrm("http://no-existe", false).vigenteEn(LocalDate.now())).isEmpty();
    }
}
