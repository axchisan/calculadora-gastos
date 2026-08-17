package com.axchisan.gastos.servicio;

import com.axchisan.gastos.dominio.AliasTarjeta;
import com.axchisan.gastos.dominio.Tarjeta;
import com.axchisan.gastos.dominio.TipoTarjeta;
import com.axchisan.gastos.dominio.Usuario;
import com.axchisan.gastos.repositorio.AliasTarjetaRepository;
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
    private final AliasTarjetaRepository alias;

    public ServicioTarjetas(TarjetaRepository tarjetas, CompraRepository compras,
                            UsuarioRepository usuarios, AliasTarjetaRepository alias) {
        this.tarjetas = tarjetas;
        this.compras = compras;
        this.usuarios = usuarios;
        this.alias = alias;
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

    // --- alias para reconocer la tarjeta en las notificaciones ---

    @Transactional(readOnly = true)
    public List<AliasTarjeta> aliasDe(UUID usuarioId, UUID tarjetaId) {
        buscar(usuarioId, tarjetaId);
        return alias.findByTarjetaId(tarjetaId);
    }

    @Transactional(readOnly = true)
    public List<AliasTarjeta> todosLosAlias(UUID usuarioId) {
        return alias.listarDelUsuario(usuarioId);
    }

    /**
     * Enseña a la aplicación a reconocer una tarjeta en las notificaciones de pago.
     *
     * @param apodo    el nombre que la tarjeta tiene dentro de Google Wallet
     * @param ultimos4 los cuatro últimos dígitos, que publica el banco
     */
    @Transactional
    public AliasTarjeta anadirAlias(UUID usuarioId, UUID tarjetaId, String apodo,
                                    String ultimos4) {
        Tarjeta tarjeta = buscar(usuarioId, tarjetaId);
        AliasTarjeta nuevo = new AliasTarjeta(tarjeta, apodo, ultimos4);

        // Que dos tarjetas del mismo usuario respondan a lo mismo dejaría la compra capturada
        // en cualquiera de las dos, y con débito y crédito de por medio eso cambia de qué mes
        // sale el dinero.
        if (alias.loUsaOtraTarjeta(usuarioId, tarjetaId, nuevo.getAliasNorm(),
                nuevo.getUltimos4())) {
            throw new IllegalArgumentException(
                    "Otra de tus tarjetas ya se reconoce con ese apodo o con esos dígitos");
        }
        return alias.save(nuevo);
    }

    @Transactional
    public void eliminarAlias(UUID usuarioId, UUID aliasId) {
        AliasTarjeta existente = alias.buscarDelUsuario(usuarioId, aliasId)
                .orElseThrow(() -> new RecursoNoEncontrado("el alias", aliasId));
        alias.delete(existente);
    }
}
