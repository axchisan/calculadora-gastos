package com.axchisan.gastos.sueldo;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.LocalDate;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

/**
 * La TRM oficial del día, tal y como la publica la Superintendencia Financiera en datos.gov.co.
 *
 * <p>Los viernes se publica una sola tasa para el sábado, el domingo y el lunes festivo si lo
 * hay: por eso cada registro trae su vigencia, y se busca el que cubre la fecha pedida.
 *
 * <p>Se guarda en memoria por fecha, de modo que solo se consulta una vez al día. Si el servicio
 * no responde, se devuelve vacío y quien llama sigue con la última TRM que tenía: no tener la
 * cifra de hoy no debe impedir ver el sueldo.
 */
@Component
public class ClienteTrm {

    private static final Logger log = LoggerFactory.getLogger(ClienteTrm.class);

    /** Una TRM con el periodo en que rige. */
    public record Trm(BigDecimal valor, LocalDate vigenteDesde, LocalDate vigenteHasta) {
    }

    private final HttpClient http = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(3))
            .build();
    private final ObjectMapper json = new ObjectMapper();
    private final ConcurrentHashMap<LocalDate, Trm> cache = new ConcurrentHashMap<>();
    private final String url;
    private final boolean habilitada;

    public ClienteTrm(
            @Value("${app.trm.url:https://www.datos.gov.co/resource/32sa-8pi3.json}") String url,
            @Value("${app.trm.habilitada:true}") boolean habilitada) {
        this.url = url;
        this.habilitada = habilitada;
    }

    /** La TRM que rige en una fecha, o vacío si no se pudo consultar. */
    public Optional<Trm> vigenteEn(LocalDate fecha) {
        if (!habilitada) {
            return Optional.empty();
        }
        Trm guardada = cache.get(fecha);
        if (guardada != null) {
            return Optional.of(guardada);
        }
        try {
            // Las diez más recientes alcanzan de sobra para cubrir un fin de semana largo.
            String consulta = url + "?$order=vigenciadesde%20DESC&$limit=10";
            HttpRequest peticion = HttpRequest.newBuilder(URI.create(consulta))
                    .timeout(Duration.ofSeconds(4))
                    .header("Accept", "application/json")
                    .GET()
                    .build();
            HttpResponse<String> respuesta = http.send(peticion, HttpResponse.BodyHandlers.ofString());
            if (respuesta.statusCode() != 200) {
                log.warn("La consulta de la TRM respondió {}", respuesta.statusCode());
                return Optional.empty();
            }
            Optional<Trm> trm = elegir(json.readTree(respuesta.body()), fecha);
            trm.ifPresent(t -> cache.put(fecha, t));
            return trm;
        } catch (Exception e) {
            log.warn("No se pudo consultar la TRM: {}", e.getMessage());
            return Optional.empty();
        }
    }

    /**
     * De la lista publicada, la que cubre la fecha. Si ninguna la cubre (la de hoy aún no se ha
     * publicado), la más reciente anterior a ella.
     */
    static Optional<Trm> elegir(JsonNode registros, LocalDate fecha) {
        Trm masReciente = null;
        for (JsonNode r : registros) {
            Trm trm = new Trm(new BigDecimal(r.path("valor").asText()),
                    LocalDate.parse(r.path("vigenciadesde").asText().substring(0, 10)),
                    LocalDate.parse(r.path("vigenciahasta").asText().substring(0, 10)));
            if (!fecha.isBefore(trm.vigenteDesde()) && !fecha.isAfter(trm.vigenteHasta())) {
                return Optional.of(trm);
            }
            if (!trm.vigenteDesde().isAfter(fecha)
                    && (masReciente == null
                    || trm.vigenteDesde().isAfter(masReciente.vigenteDesde()))) {
                masReciente = trm;
            }
        }
        return Optional.ofNullable(masReciente);
    }
}
