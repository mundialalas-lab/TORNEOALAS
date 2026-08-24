# Orden de los archivos

| Archivo | Cuándo | Qué hace |
|---|---|---|
| `0001_mundial_alas.sql` | Ya corrido | El esquema completo: tablas, vistas, funciones y políticas. |
| `CREAR_CAPITANES.sql` | **No está acá** | Crea las cuentas de los 8 capitanes y sus perfiles. |
| `0003_cerrar_escritura_publica.sql` | Último | Cierra la escritura pública. |

## Por qué falta `CREAR_CAPITANES.sql`

Porque tiene las claves adentro y este repositorio es público. Lo que entra
al historial de git queda ahí aunque después se borre el archivo — la misma
razón por la que existe el `.gitignore` de la raíz.

Vive fuera del proyecto: se pega en el SQL Editor de Supabase, se corre, y se
borra. Si se pierde, se vuelve a armar: por cada capitán hace falta una fila
en `auth.users` (con su identidad en `auth.identities`, o el login con clave
no funciona) y una en `profiles` que la ate a su equipo.

## Por qué `0003` va último

Hasta que ese archivo corra, cualquiera con la anon key puede escribir en la
base. Pero si corre **antes** de que los capitanes tengan cuenta, la app deja
de poder guardar: primero todos tienen que poder entrar, después se cierra
la puerta.
