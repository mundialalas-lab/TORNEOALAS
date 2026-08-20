# Mundial ALAS 2026

Fixture, tabla de posiciones, llave y álbum de figuritas del torneo interno de ALAS.

Toda la app es **un solo archivo HTML** que se abre en el navegador. No necesita
servidor, ni instalar nada, ni conexión: se puede abrir con doble clic y funciona
igual proyectada al costado de la cancha.

## Cómo se abre

| Cómo | Qué hacer |
|---|---|
| Rápido | Doble clic en `ALAS-MUNDIAL.html` |
| Con sonido de intro | Doble clic en `Abrir Mundial ALAS (con sonido).bat` |
| Servidor local | Cualquier servidor estático sobre esta carpeta y entrar a `index.html` |

El `.bat` existe porque Chrome bloquea el audio hasta que alguien toca la
pantalla: abre el navegador con la política de reproducción relajada para que la
intro arranque sola.

## Los tres roles

Al salir de la intro aparece la pantalla "¿Quién sos?":

- **Hincha** — mira el torneo y arma su álbum. Entra sólo con nombre y apellido.
- **Capitán** — además carga y edita el plantel **de su equipo**, y de ningún otro.
  El administrador es quien crea el usuario del capitán y le asigna el equipo.
- **Administrador** — controla todo: resultados, equipos, formato y capitanes.

## Cómo se carga un partido

En **Cargar resultados** (que sólo ve el administrador), tocando un partido se
abre la consola de registro. Se anota en tres toques, que es el orden en que se
anota al costado de la cancha:

1. **Qué pasó** — Gol, Amarilla, Roja o Figura
2. **De qué equipo**
3. **Quién** — aparece el plantel y se toca al jugador

Si el equipo todavía no tiene plantel cargado, se puede dar de alta al jugador
ahí mismo sin salir del partido. Al cargar goles, el marcador se ajusta solo.

Todo lo que se registra acá alimenta la tabla de posiciones, la llave y las
estadísticas. No hay ningún dato que mantener a mano por duplicado.

## Base de datos

`supabase/migrations/0001_mundial_alas.sql` traduce todo el modelo a tablas de
Postgres, con las vistas que reemplazan los cálculos que hoy hace el navegador
(posiciones, goleadores, disciplina, suspendidos, figuras y el valor de cada
figurita), y las políticas de RLS que hacen valer los tres roles del lado del
servidor.

Se pega entero en el SQL Editor de Supabase. Es idempotente: se puede volver a
correr sin duplicar nada, y no pisa los resultados ya cargados.

Trae el sorteo y el fixture oficiales: dos grupos, ocho equipos con su país y su
capitán, y los doce partidos con fecha y sede.

## Sobre la clave de administrador

En el código **no está la clave**: está su huella SHA-256.

Que quede clara la medida de esto: una huella de un PIN de seis dígitos se
revierte probando el millón de combinaciones, y eso a una computadora le lleva un
segundo. **Esto no convierte la clave en secreta.** Sirve para que no aparezca al
leer el archivo ni en las búsquedas de GitHub, nada más.

Mientras la app funcione sola contra el navegador, cualquier control de acceso
que viva en ella es una separación de responsabilidades —que nadie toque el
fixture por accidente— y no una protección real. La clave de verdad tiene que
vivir en Supabase (`auth.users`), que es lo único que puede validarla sin
entregarla; las políticas de RLS de la migración ya están escritas para eso.

## Qué hay en la carpeta

| Archivo | Qué es |
|---|---|
| `ALAS-MUNDIAL.html` | La app entera |
| `index.html` · `ALAS-ALBUM.html` | Atajos que redirigen a la app |
| `supabase/migrations/` | El esquema de la base |
| `ALAS.png` · `ALAS_blanco.png` | Logo institucional (el segundo, en blanco sobre transparente, es el de la barra) |
| `cancha_web.jpg` · `PELOTA.jpg` · `FIFA.jpg` | Fondos |
| `COPA.jpg` · `Album.jpg` · `LLAVE.jpg` | Imágenes de la interfaz |
| `videoplayback.mp4` | Video de la intro |
| `Abrir Mundial ALAS (con sonido).bat` | Lanzador con audio |
