package com.axchisan.gastos.servicio;

import com.axchisan.gastos.dominio.Cuenta;
import com.axchisan.gastos.dominio.TipoCuenta;
import com.axchisan.gastos.dominio.Usuario;
import com.axchisan.gastos.repositorio.CuentaRepository;
import com.axchisan.gastos.repositorio.UsuarioRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/** Los saldos reales de cada banco, billetera y del efectivo. */
@Service
public class ServicioCuentas {

    private final CuentaRepository cuentas;
    private final UsuarioRepository usuarios;
    private final CambiosDeCuentas cambios;

    public ServicioCuentas(CuentaRepository cuentas, UsuarioRepository usuarios,
                           CambiosDeCuentas cambios) {
        this.cuentas = cuentas;
        this.usuarios = usuarios;
        this.cambios = cambios;
    }

    /** Las cuentas, cada una con lo apuntado desde que se anotó su saldo. */
    @Transactional(readOnly = true)
    public List<Cuenta> listar(UUID usuarioId) {
        List<Cuenta> lista = cuentas.listarDelUsuario(usuarioId);
        cambios.calcular(usuarioId, lista);
        return lista;
    }

    @Transactional
    public Cuenta crear(UUID usuarioId, String nombre, TipoCuenta tipo, BigDecimal saldo,
                        LocalDate saldoAl) {
        Usuario usuario = usuarios.findById(usuarioId)
                .orElseThrow(() -> new RecursoNoEncontrado("el usuario", usuarioId));
        Cuenta cuenta = new Cuenta(usuario, nombre, tipo);
        cuenta.registrarSaldo(saldo == null ? BigDecimal.ZERO : saldo, saldoAl);
        cuenta.setOrden((short) cuentas.listarDelUsuario(usuarioId).size());
        return cuentas.save(cuenta);
    }

    @Transactional
    public Cuenta actualizar(UUID usuarioId, UUID cuentaId, String nombre, TipoCuenta tipo,
                             BigDecimal saldo, LocalDate saldoAl, Boolean activa) {
        Cuenta cuenta = cuentas.buscarDelUsuario(usuarioId, cuentaId)
                .orElseThrow(() -> new RecursoNoEncontrado("la cuenta", cuentaId));
        if (nombre != null) {
            cuenta.setNombre(nombre);
        }
        if (tipo != null) {
            cuenta.setTipo(tipo);
        }
        if (saldo != null) {
            cuenta.registrarSaldo(saldo, saldoAl);
        }
        if (activa != null) {
            cuenta.setActiva(activa);
        }
        Cuenta guardada = cuentas.saveAndFlush(cuenta);
        // El cambio depende de las demás cuentas (cuál es la principal), así que se calcula
        // sobre la lista entera.
        List<Cuenta> todas = cuentas.listarDelUsuario(usuarioId);
        cambios.calcular(usuarioId, todas);
        todas.stream().filter(c -> c.getId().equals(guardada.getId())).findFirst()
                .ifPresent(c -> guardada.setCambio(c.getCambio()));
        return guardada;
    }

    @Transactional
    public void eliminar(UUID usuarioId, UUID cuentaId) {
        Cuenta cuenta = cuentas.buscarDelUsuario(usuarioId, cuentaId)
                .orElseThrow(() -> new RecursoNoEncontrado("la cuenta", cuentaId));
        cuentas.delete(cuenta);
    }
}
