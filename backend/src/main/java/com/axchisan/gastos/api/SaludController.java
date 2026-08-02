package com.axchisan.gastos.api;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.OffsetDateTime;
import java.util.Map;

/** Comprobación de vida del servicio; sirve además para «calentar» la función Lambda. */
@RestController
@Tag(name = "Estado")
public class SaludController {

    @GetMapping("/api/salud")
    @Operation(summary = "Indica si el servicio responde")
    public Map<String, Object> salud() {
        return Map.of(
                "estado", "ok",
                "instante", OffsetDateTime.now().toString());
    }
}
