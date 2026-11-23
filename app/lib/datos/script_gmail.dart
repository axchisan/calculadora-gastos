/// El Google Apps Script que reenvía los correos de alertas de Bancolombia.
///
/// Se pega en script.google.com con la cuenta de Gmail del usuario. Corre cada 5 minutos en
/// los servidores de Google, así que no depende del teléfono ni del Mac. Solo envía la frase
/// del aviso («Bancolombia: Compraste…»), nunca el correo entero, y solo de correos que Gmail
/// verificó como firmados (DKIM) por el dominio de notificaciones del banco.
String scriptGmail({required String urlApi, required String clave}) =>
    _plantilla.replaceAll('{{API}}', urlApi).replaceAll('{{CLAVE}}', clave);

const String _plantilla = r'''
// Mis gastos: reenvía las alertas de Bancolombia a la app.
// 1. Pega esto en un proyecto nuevo de https://script.google.com
// 2. Elige la función «instalar» y pulsa Ejecutar. Acepta los permisos de Gmail.
// Desde ahí revisa el correo cada 5 minutos. Para apagarlo, borra el proyecto o revoca la
// clave «Gmail» en la app (Ajustes → Registro automático).

const API = '{{API}}';
const CLAVE = '{{CLAVE}}';
const BUSQUEDA = 'from:(alertasynotificaciones@an.notificacionesbancolombia.com OR ' +
    'alertasynotificaciones@ayn.notificacionesbancolombia.com) newer_than:2d';

function instalar() {
  ScriptApp.getProjectTriggers().forEach(function (t) { ScriptApp.deleteTrigger(t); });
  ScriptApp.newTrigger('revisar').timeBased().everyMinutes(5).create();
  revisar();
}

function revisar() {
  const propiedades = PropertiesService.getScriptProperties();
  const ultimo = Number(propiedades.getProperty('ultimo') || 0);
  let masReciente = ultimo;
  const avisos = [];
  GmailApp.search(BUSQUEDA, 0, 50).forEach(function (hilo) {
    hilo.getMessages().forEach(function (mensaje) {
      const fecha = mensaje.getDate().getTime();
      if (fecha <= ultimo || !firmadoPorElBanco(mensaje)) return;
      const frase = fraseDelAviso(mensaje.getPlainBody());
      if (frase) avisos.push({ origen: 'CORREO', texto: frase });
      masReciente = Math.max(masReciente, fecha);
    });
  });
  if (avisos.length > 0) {
    const respuesta = UrlFetchApp.fetch(API + '/api/ingesta/avisos', {
      method: 'post',
      contentType: 'application/json',
      headers: { 'X-Clave-Ingesta': CLAVE },
      payload: JSON.stringify({ avisos: avisos.slice(0, 200) }),
      muteHttpExceptions: true,
    });
    if (respuesta.getResponseCode() >= 300) {
      console.error(respuesta.getResponseCode() + ' ' + respuesta.getContentText());
      return; // Se reintenta en la siguiente vuelta.
    }
  }
  propiedades.setProperty('ultimo', String(masReciente));
}

// Gmail ya comprobó la firma DKIM; se exige que venga del dominio del banco.
function firmadoPorElBanco(mensaje) {
  const cabeceras = mensaje.getRawContent().slice(0, 30000);
  return /dkim=pass[^;]*notificacionesbancolombia\.com/i.test(cabeceras);
}

// El aviso es la misma frase que llega por SMS, dentro de una tabla: se corta en «Estamos
// cerca.», en el borde de la celda o a los 400 caracteres, para no mandar el resto del correo.
function fraseDelAviso(cuerpo) {
  const limpio = cuerpo.replace(/\s+/g, ' ');
  const inicio = limpio.indexOf('Bancolombia: ');
  if (inicio < 0) return null;
  let frase = limpio.slice(inicio, inicio + 400);
  const cierre = frase.indexOf('Estamos cerca.');
  if (cierre > 0) frase = frase.slice(0, cierre + 'Estamos cerca.'.length);
  const borde = frase.indexOf('|');
  if (borde > 0) frase = frase.slice(0, borde);
  return frase.trim();
}
''';
