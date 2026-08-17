package com.axchisan.gastos.servicio;

import com.axchisan.gastos.dominio.Tarjeta;
import com.axchisan.gastos.dominio.TipoTarjeta;
import com.axchisan.gastos.dominio.Usuario;
import com.axchisan.gastos.repositorio.CompraRepository;
import com.axchisan.gastos.repositorio.TarjetaRepository;
import com.axchisan.gastos.repositorio.UsuarioRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

/** Las tarjetas con las que se paga y su ciclo de facturación. */
@Service
public class ServicioTarjetas {

    private final TarjetaRepository tarjetas;
    private final CompraRepository compras;
    private final UsuarioRepository usuarios;

    public ServicioTarjetas(TarjetaRepository tarjetas, CompraRepository compras,
                            UsuarioRepository usuarios) {
        this.tarjetas = tarjetas;
        this.compras = compras;
        this.usuarios = usuarios;
    }

    @Transactional(readOnly = true)
    public List<Tarjeta> listar(UUID usuarioId) {
        return tarjetas.listarDelUsuario(usuarioId);
    }

    @Transactional(readOnly = true)
    public Tarjeta buscar(UUID usuarioId, UUID tarjetaId) {
        return tarjetas.buscarDelUsuario(usuarioId, tarjetaId)
                .orElseThrow(() -> new RecursoNoEncontrado("la tarjeta", tarjetaId));
    }

    @Transactional
    public Tarjeta crear(UUID usuarioId, String nombre, TipoTarjeta tipo, Integer diaCorte,
                         Integer diaPago, String color) {
        Usuario usuario = usuarios.findById(usuarioId)
                .orElseThrow(() -> new RecursoNoEncontrado("el usuario", usuarioId));

        Tarjeta tarjeta = new Tarjeta(usuario, nombre, tipo);
        tarjeta.definirCiclo(diaCorte, diaPago);
        tarjeta.setColor(color);
        return tarjetas.save(tarjeta);
    }

    /**
     * Modifica una tarjeta.
     *
     * <p>El tipo no se puede cambiar: las compras ya registradas calcularon su mes de pago con
     * el ciclo de la tarjeta, y convertir una de crédito en débito dejaría esos cálculos sin
     * respaldo. Para eso se archiva la tarjeta y se crea otra.
     */
    @Transactional
    public Tarjeta actualizar(UUID usuarioId, UUID tarjetaId, String nombre, Integer diaCorte,
                              Integer diaPago, String color, Boolean activa) {
        Tarjeta tarjeta = buscar(usuarioId, tarjetaId);

        if (nombre != null) {
            tarjeta.setNombre(nombre);
        }
        if (color != null) {
            tarjeta.setColor(color);
        }
        if (activa != null) {
            tarjeta.setActiva(activa);
        }
        // Cambiar el ciclo afecta solo a lo que se compre a partir de ahora: las compras ya
        // registradas guardan su mes de pago y conservan el que de verdad tuvieron.
        if (diaCorte != null || diaPago != null) {
            tarjeta.definirCiclo(
                    diaCorte != null ? diaCorte
                            : tarjeta.getDiaCorte() == null ? null : (int) tarjeta.getDiaCorte(),
                    diaPago != null ? diaPago
                            : tarjeta.getDiaPago() == null ? null : (int) tarjeta.getDiaPago());
        }
        return tarjetas.save(tarjeta);
    }

    /**
     * Elimina una tarjeta que no se haya usado nunca.
     *
     * <p>Si tiene compras asociadas se archiva en lugar de borrarse: quitarla dejaría esas
     * compras sin explicar de dónde salió el dinero.
     */
    @Transactional
    public void eliminar(UUID usuarioId, UUID tarjetaId) {
        Tarjeta tarjeta = buscar(usuarioId, tarjetaId);

        if (compras.countByTarjetaId(tarjetaId) > 0) {
            tarjeta.setActiva(false);
            tarjetas.save(tarjeta);
            return;
        }
        tarjetas.delete(tarjeta);
    }
}
