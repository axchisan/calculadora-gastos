package com.axchisan.gastos.repositorio;

import com.axchisan.gastos.dominio.Usuario;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;
import java.util.UUID;

public interface UsuarioRepository extends JpaRepository<Usuario, UUID> {

    /**
     * Busca por correo, ignorando mayúsculas.
     *
     * <p>La comparación replica el índice único {@code lower(email)} de la base de datos, de modo
     * que la consulta puede aprovecharlo.
     */
    @Query("SELECT u FROM Usuario u WHERE lower(u.email) = lower(:email)")
    Optional<Usuario> buscarPorEmail(@Param("email") String email);

    @Query("SELECT count(u) > 0 FROM Usuario u WHERE lower(u.email) = lower(:email)")
    boolean existeConEmail(@Param("email") String email);
}
