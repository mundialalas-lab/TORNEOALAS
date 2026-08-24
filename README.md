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

## Sobre las claves

En el código **no hay ninguna clave**, ni en texto plano ni como huella.

Antes sí las había: las ocho contraseñas de los capitanes estaban escritas en
el HTML, y este README afirmaba que del administrador sólo quedaba un hash
SHA-256 —lo cual tampoco era cierto, porque seguía viva una constante
`ADMIN_KEY` con la clave adentro. Todo eso se fue.

Hoy las claves viven en `auth.users` de Supabase, que es lo único que puede
validarlas sin entregarlas, y el rol de cada persona sale de la tabla
`profiles`. Un capitán ya no "entra" comparando texto contra el archivo: abre
una sesión de verdad, y el servidor es el que decide qué puede tocar.

Cómo entra cada uno:

| Rol | Entra con | Dónde se valida |
|---|---|---|
| Hincha | Nombre y apellido | En el navegador. No escribe nada en la base. |
| Capitán | Su usuario y su PIN de siempre | `auth.users` — la app traduce el usuario a `<usuario>@mundialalas.app` y expande el PIN antes de mandarlo |
| Administrador | Email y clave | `auth.users`, y además `profiles.role` tiene que decir `admin` |

Que quede clara la medida de esto: **el PIN del capitán sigue siendo de cuatro
dígitos**, y la fórmula que lo expande está a la vista en el HTML. No se ganó
fuerza de clave. Lo que se ganó es otra cosa, y es la que importaba: la
autorización dejó de vivir en el navegador. Antes, un control de acceso escrito
en la app era una separación de responsabilidades —que nadie toque el fixture
por accidente— y cualquiera podía saltearlo desde la consola. Ahora lo hace
valer Postgres con RLS, del lado del servidor, donde no se puede discutir.

Si querés claves de verdad, el cambio es chico y no toca el código: poné PINs
de seis dígitos o más al crear las cuentas, y listo.

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
