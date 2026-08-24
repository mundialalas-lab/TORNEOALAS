-- =====================================================================
--  MUNDIAL ALAS — cerrar la escritura pública
--
--  QUÉ ESTÁ PASANDO HOY (verificado el 24/8/2026 contra la base real)
--  ------------------------------------------------------------------
--  Estas seis tablas aceptan escrituras de CUALQUIERA que tenga la anon
--  key — que está dentro del HTML, en un repositorio público:
--
--      tournaments · groups · teams · players · matches · match_events
--
--  Se comprobó insertando y borrando una fila de prueba en players: la
--  insertó (201) y la borró (204) sin ninguna sesión. Es decir que hoy
--  cualquiera puede vaciar el plantel de los 149 jugadores o reescribir
--  todos los resultados desde la consola del navegador.
--
--  Las otras cuatro (legends, profiles, albums, album_stickers) sí están
--  protegidas. Por eso syncUsersToSupabase(), que escribe en legends,
--  viene fallando en silencio desde siempre.
--
--  Lo más probable es que en algún momento las escrituras empezaron a
--  fallar y se resolvió abriendo las tablas en vez de darle identidad a
--  quien escribe. Este archivo revierte eso y deja las políticas que
--  0001 ya tenía escritas.
--
--  ORDEN — ESTO VA ÚLTIMO
--  ----------------------
--  Si lo corrés antes de que la app sepa autenticar, la app deja de
--  poder guardar. La secuencia es:
--
--    1. Correr CREAR_CAPITANES.sql — crea las 8 cuentas y sus perfiles.
--       Ese archivo NO está en el repositorio a propósito: tiene las
--       claves adentro, y el repositorio es público.
--    2. Publicar el HTML nuevo.
--    3. Probar: entrar como capitán y guardar un jugador.
--    4. Recién ahí, correr ESTE archivo.
--
--  Es idempotente.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Qué políticas hay AHORA. Mirá este resultado antes de seguir: es la
--    foto de lo que este script va a reemplazar.
-- ---------------------------------------------------------------------
select tablename,
       policyname,
       roles,
       cmd,
       qual        as usando,
       with_check  as con_check
  from pg_policies
 where schemaname = 'public'
   and tablename in ('tournaments','groups','teams','players','matches','match_events')
 order by tablename, policyname;


-- ---------------------------------------------------------------------
-- 2. Borrón y cuenta nueva sobre esas seis tablas.
--    Se borra TODA política existente —no sólo las que 0001 conocía,
--    porque la que abrió la puerta puede llamarse de cualquier forma— y
--    se vuelve a crear únicamente lo que corresponde.
-- ---------------------------------------------------------------------
do $$
declare
  t   text;
  pol record;
  n   int := 0;
begin
  foreach t in array array['tournaments','groups','teams','players','matches','match_events']
  loop
    -- RLS puede estar directamente apagada: encenderla es lo primero.
    execute format('alter table public.%I enable row level security', t);

    for pol in
      select policyname from pg_policies
       where schemaname='public' and tablename=t
    loop
      execute format('drop policy %I on public.%I', pol.policyname, t);
      n := n + 1;
    end loop;
  end loop;
  raise notice 'Políticas viejas eliminadas: %', n;
end $$;


-- ---------------------------------------------------------------------
-- 3. Las políticas que corresponden (idénticas a 0001).
--    Mirar es libre: la app se proyecta al costado de la cancha.
--    Escribir exige sesión, y el rol lo dice profiles.
-- ---------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['tournaments','groups','teams','players','matches','match_events']
  loop
    execute format(
      'create policy "lectura publica" on public.%I for select to anon, authenticated using (true)', t);
  end loop;
end $$;

create policy "admin escribe torneo" on public.tournaments
  for all to authenticated
  using (public.es_admin(id)) with check (public.es_admin(id));

create policy "admin escribe grupos" on public.groups
  for all to authenticated
  using (public.es_admin(tournament_id)) with check (public.es_admin(tournament_id));

create policy "admin escribe equipos" on public.teams
  for all to authenticated
  using (public.es_admin(tournament_id)) with check (public.es_admin(tournament_id));

create policy "admin escribe partidos" on public.matches
  for all to authenticated
  using (public.es_admin(tournament_id)) with check (public.es_admin(tournament_id));

create policy "admin escribe eventos" on public.match_events
  for all to authenticated
  using (exists (select 1 from public.matches m
                 where m.id = match_id and public.es_admin(m.tournament_id)))
  with check (exists (select 1 from public.matches m
                      where m.id = match_id and public.es_admin(m.tournament_id)));

-- El capitán manda en SU plantel y en ninguno más. Es la misma regla que
-- puedeEditarEquipo() en la app — pero esta no se puede saltear desde la
-- consola del navegador, que es la diferencia que importa.
create policy "plantel propio o admin" on public.players
  for all to authenticated
  using      (public.es_admin(tournament_id) or public.es_capitan_de(team_id))
  with check (public.es_admin(tournament_id) or public.es_capitan_de(team_id));


-- ---------------------------------------------------------------------
-- 4. Cómo quedó. Cada tabla tiene que mostrar rowsecurity = true.
-- ---------------------------------------------------------------------
select c.relname                                  as tabla,
       c.relrowsecurity                           as rls_activa,
       count(p.policyname)                        as politicas
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  left join pg_policies p
         on p.schemaname = 'public' and p.tablename = c.relname
 where n.nspname = 'public'
   and c.relname in ('tournaments','groups','teams','players','matches','match_events',
                     'legends','profiles','albums','album_stickers')
 group by c.relname, c.relrowsecurity
 order by c.relname;
