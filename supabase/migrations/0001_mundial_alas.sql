-- =====================================================================
--  MUNDIAL ALAS — esquema para Supabase
--  Traducción del estado que hoy vive en localStorage (alas-torneo-v3)
--  a tablas relacionales, con las vistas que reemplazan los cálculos
--  que la app hace en JavaScript.
--
--  Ejecutar entero en el SQL Editor de Supabase. Es idempotente:
--  se puede volver a correr sin romper nada.
--
--  Orden: extensiones → tipos → tablas → índices → triggers → vistas
--         → funciones de permisos → RLS → semilla opcional.
-- =====================================================================

-- gen_random_uuid() viene en el núcleo de Postgres desde la 13, así que
-- no hace falta habilitar pgcrypto: una extensión menos de la que
-- depender.

-- ---------------------------------------------------------------------
-- 1. TIPOS
--    Salen tal cual de los diccionarios de la app (POS_LABEL,
--    STATUS_LABEL, EVENT_LABEL, ROL).
-- ---------------------------------------------------------------------
do $$ begin
  create type public.match_phase  as enum ('group','knockout');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.match_status as enum ('scheduled','live','finished','suspended');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.event_type   as enum ('goal','assist','yellow','red');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.player_pos   as enum ('ARQ','DEF','MED','DEL');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.app_role     as enum ('hincha','capitan','admin');
exception when duplicate_object then null; end $$;

-- De qué depende cada lado de un cruce. En la fase de grupos siempre es
-- 'team'; en la llave el rival sale de una posición de grupo o del
-- resultado de otro partido.
do $$ begin
  create type public.slot_source  as enum ('team','group_pos','match_winner','match_loser');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.tie_winner   as enum ('home','away');
exception when duplicate_object then null; end $$;


-- ---------------------------------------------------------------------
-- 2. TABLAS
-- ---------------------------------------------------------------------

-- Un torneo por edición. Lo que en el estado eran los objetos
-- `tournament`, `format` y `settings` son columnas de acá: no tiene
-- sentido una tabla de una sola fila por cada uno.
create table if not exists public.tournaments (
  id                        uuid primary key default gen_random_uuid(),
  name                      text not null,
  subtitle                  text not null default '',
  season                    text,

  -- format
  num_groups                smallint not null default 2  check (num_groups between 1 and 12),
  teams_per_group           smallint not null default 4  check (teams_per_group between 2 and 32),
  qualifiers_per_group      smallint not null default 2  check (qualifiers_per_group between 1 and 8),
  double_round_robin        boolean  not null default false,
  third_place_match         boolean  not null default true,
  h2h_tiebreak              boolean  not null default false,
  yellow_cards_suspension   smallint not null default 2  check (yellow_cards_suspension between 1 and 5),
  red_card_suspension       smallint not null default 1  check (red_card_suspension between 1 and 5),

  -- settings de presentación
  sound_enabled             boolean not null default true,
  confetti_enabled          boolean not null default true,
  volume                    real    not null default 0.7 check (volume between 0 and 1),
  theme                     text    not null default 'dark',

  is_active                 boolean not null default true,
  legacy_id                 text,          -- id del localStorage, para importar una vez
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now()
);

comment on column public.tournaments.legacy_id is
  'Id que tenía el registro en localStorage. Sólo sirve para resolver las relaciones durante la importación inicial; después se puede ignorar.';


create table if not exists public.groups (
  id             uuid primary key default gen_random_uuid(),
  tournament_id  uuid not null references public.tournaments(id) on delete cascade,
  name           text not null,
  sort_order     smallint not null default 0,
  legacy_id      text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (tournament_id, name),
  unique (tournament_id, legacy_id)
);


create table if not exists public.teams (
  id               uuid primary key default gen_random_uuid(),
  tournament_id    uuid not null references public.tournaments(id) on delete cascade,
  group_id         uuid references public.groups(id) on delete set null,
  name             text not null,
  short_name       text not null,
  city             text not null default '',
  category         text not null default '',
  -- Cada área de la empresa juega representando a un país. `country` es la
  -- clave de la bandera ('py', 'de', 'en', …) y `country_name` el nombre
  -- que se imprime en el afiche del sorteo ('Paraguay', 'Alemania', …).
  country          text not null default '',
  country_name     text not null default '',
  -- "Capitán / Representante" del afiche. Es una etiqueta del equipo, no
  -- un login: el usuario con el que el capitán entra a cargar su plantel
  -- vive en profiles, y puede no existir todavía.
  captain_name     text not null default '',
  color_primary    text not null default '#2f7ff0',
  color_secondary  text not null default '#0f3f96',
  -- Antes eran data URIs dentro del JSON. Acá van a Supabase Storage y
  -- se guarda la ruta; ver la nota del final sobre los buckets.
  logo_path        text,
  photo_path       text,
  sort_order       smallint not null default 0,
  legacy_id        text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (tournament_id, name),
  unique (tournament_id, legacy_id)
);


create table if not exists public.players (
  id             uuid primary key default gen_random_uuid(),
  tournament_id  uuid not null references public.tournaments(id) on delete cascade,
  team_id        uuid not null references public.teams(id) on delete cascade,
  first_name     text not null,
  last_name      text not null,
  -- el dorsal puede faltar: en la cancha muchas veces se anota primero
  -- el nombre y el número aparece después
  number         smallint check (number between 0 and 99),
  position       public.player_pos not null default 'DEL',
  birth_date     date,
  photo_path     text,
  legacy_id      text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (tournament_id, legacy_id)
);

-- `create table if not exists` no agrega columnas a una tabla que ya
-- existe, así que las nuevas se suman aparte para que este archivo se
-- pueda volver a correr sobre una base creada con la versión anterior.
alter table public.teams add column if not exists country_name text not null default '';
alter table public.teams add column if not exists captain_name text not null default '';


-- Dos jugadores del mismo equipo no pueden compartir dorsal, pero sí
-- pueden quedar los dos sin número cargado.
create unique index if not exists players_team_number_uniq
  on public.players (team_id, number) where number is not null;


create table if not exists public.matches (
  id              uuid primary key default gen_random_uuid(),
  tournament_id   uuid not null references public.tournaments(id) on delete cascade,
  phase           public.match_phase not null default 'group',
  group_id        uuid references public.groups(id) on delete set null,

  -- fase de grupos
  round           smallint,
  -- llave
  bracket_round   smallint,
  bracket_order   smallint,
  round_title     text,
  label           text,

  -- De dónde sale cada lado. home_team_id / away_team_id quedan en null
  -- hasta que el cruce se define; cuando se resuelve, se escriben. Así
  -- las vistas no tienen que recorrer la llave hacia atrás.
  home_source     public.slot_source not null default 'team',
  home_team_id    uuid references public.teams(id) on delete set null,
  home_group_id   uuid references public.groups(id) on delete set null,
  home_group_pos  smallint,
  home_match_id   uuid references public.matches(id) on delete set null,

  away_source     public.slot_source not null default 'team',
  away_team_id    uuid references public.teams(id) on delete set null,
  away_group_id   uuid references public.groups(id) on delete set null,
  away_group_pos  smallint,
  away_match_id   uuid references public.matches(id) on delete set null,

  match_date      date,
  match_time      time,
  venue           text not null default '',
  status          public.match_status not null default 'scheduled',

  score_home      smallint check (score_home between 0 and 99),
  score_away      smallint check (score_away between 0 and 99),

  -- serie de ida y vuelta
  two_legs        boolean not null default false,
  date_leg2       date,
  score_home_leg2 smallint check (score_home_leg2 between 0 and 99),
  score_away_leg2 smallint check (score_away_leg2 between 0 and 99),

  -- sólo se usa cuando el global termina empatado
  tie_break_winner public.tie_winner,

  mvp_player_id   uuid references public.players(id) on delete set null,

  legacy_id       text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (tournament_id, legacy_id),

  -- coherencia de cada lado según su origen
  constraint matches_home_slot_ok check (
    case home_source
      when 'team'         then home_group_id is null and home_group_pos is null and home_match_id is null
      when 'group_pos'    then home_group_id is not null and home_group_pos is not null and home_match_id is null
      else                     home_match_id is not null and home_group_id is null and home_group_pos is null
    end
  ),
  constraint matches_away_slot_ok check (
    case away_source
      when 'team'         then away_group_id is null and away_group_pos is null and away_match_id is null
      when 'group_pos'    then away_group_id is not null and away_group_pos is not null and away_match_id is null
      else                     away_match_id is not null and away_group_id is null and away_group_pos is null
    end
  ),
  -- un equipo no juega contra sí mismo
  constraint matches_distintos check (
    home_team_id is null or away_team_id is null or home_team_id <> away_team_id
  ),
  -- los goles de la vuelta sólo existen si la serie es de ida y vuelta
  constraint matches_leg2_ok check (
    two_legs or (score_home_leg2 is null and score_away_leg2 is null and date_leg2 is null)
  ),
  -- los partidos de grupo pertenecen a un grupo; los de llave, no
  constraint matches_grupo_ok check (
    (phase = 'group' and group_id is not null) or (phase = 'knockout')
  )
);


-- Goles, asistencias y tarjetas. Es lo que alimenta las tablas de
-- goleadores y disciplina, y el valor de cada figurita.
create table if not exists public.match_events (
  id          uuid primary key default gen_random_uuid(),
  match_id    uuid not null references public.matches(id) on delete cascade,
  team_id     uuid not null references public.teams(id) on delete cascade,
  player_id   uuid not null references public.players(id) on delete cascade,
  type        public.event_type not null,
  minute      smallint check (minute between 0 and 130),
  -- 1 = ida, 2 = vuelta
  leg         smallint not null default 1 check (leg in (1,2)),
  legacy_id   text,
  created_at  timestamptz not null default now()
);


-- Históricos que se cargan a mano y salen como cartas doradas.
create table if not exists public.legends (
  id             uuid primary key default gen_random_uuid(),
  tournament_id  uuid not null references public.tournaments(id) on delete cascade,
  name           text not null,
  team           text not null default '',
  country        text not null default '',
  position       public.player_pos not null default 'DEL',
  ovr            smallint not null default 90 check (ovr between 45 and 99),
  year           text not null default '',
  note           text not null default '',
  photo_path     text,
  legacy_id      text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (tournament_id, legacy_id)
);


-- ---------------------------------------------------------------------
-- 3. PERSONAS Y ÁLBUM
--
--  OJO con las claves: hoy la app guarda usuario y contraseña en texto
--  plano dentro del HTML, y eso servía para separar responsabilidades,
--  no para proteger nada. En Supabase eso NO se replica: la
--  autenticación la maneja auth.users y acá sólo queda el rol.
--  Un capitán se crea invitándolo por email desde el panel de Supabase
--  (o con signUp) y después se le asigna el equipo en profiles.
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id             uuid primary key default gen_random_uuid(),
  tournament_id  uuid not null references public.tournaments(id) on delete cascade,
  -- null para los hinchas que entran sólo con nombre y apellido, sin
  -- cuenta. Si se activa el login anónimo de Supabase, se completa.
  user_id        uuid references auth.users(id) on delete cascade,
  display_name   text not null,
  role           public.app_role not null default 'hincha',
  -- sólo para capitanes: el equipo que pueden editar
  team_id        uuid references public.teams(id) on delete set null,
  last_seen_at   timestamptz not null default now(),
  legacy_id      text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (tournament_id, legacy_id),
  -- una cuenta, un perfil por torneo
  unique (tournament_id, user_id),
  -- un capitán sin equipo no puede editar nada; un hincha con equipo no
  -- tiene sentido
  constraint profiles_capitan_con_equipo check (
    (role = 'capitan' and team_id is not null) or (role <> 'capitan' and team_id is null)
  ),
  -- capitán y admin necesitan cuenta de verdad
  constraint profiles_login_obligatorio check (
    role = 'hincha' or user_id is not null
  )
);

-- Dos hinchas no pueden llamarse igual, pero un hincha y un capitán sí
-- (es la misma regla que ya aplica createUser en la app).
create unique index if not exists profiles_nombre_por_rol_uniq
  on public.profiles (tournament_id, role, lower(display_name));


create table if not exists public.albums (
  id              uuid primary key default gen_random_uuid(),
  tournament_id   uuid not null references public.tournaments(id) on delete cascade,
  profile_id      uuid not null references public.profiles(id) on delete cascade,
  packs           integer not null default 1 check (packs >= 0),
  last_pack_date  date,
  muted           boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (tournament_id, profile_id)
);

-- El `collection: {numeroDeFigurita: cantidad}` del estado, normalizado.
-- La cantidad puede pasar de 1: las repetidas son las que se cambian.
create table if not exists public.album_stickers (
  album_id        uuid not null references public.albums(id) on delete cascade,
  sticker_number  integer not null check (sticker_number > 0),
  copies          integer not null default 1 check (copies > 0),
  first_got_at    timestamptz not null default now(),
  primary key (album_id, sticker_number)
);


-- ---------------------------------------------------------------------
-- 4. ÍNDICES
--    Los de las claves foráneas que se filtran seguido. Postgres no los
--    crea solo.
-- ---------------------------------------------------------------------
create index if not exists groups_tournament_idx        on public.groups (tournament_id, sort_order);
create index if not exists teams_tournament_idx         on public.teams (tournament_id);
create index if not exists teams_group_idx              on public.teams (group_id);
create index if not exists players_team_idx             on public.players (team_id);
create index if not exists players_tournament_idx       on public.players (tournament_id);
create index if not exists matches_tournament_idx       on public.matches (tournament_id, phase);
create index if not exists matches_group_idx            on public.matches (group_id, round);
create index if not exists matches_home_team_idx        on public.matches (home_team_id);
create index if not exists matches_away_team_idx        on public.matches (away_team_id);
create index if not exists matches_fecha_idx            on public.matches (tournament_id, match_date, match_time);
create index if not exists match_events_match_idx       on public.match_events (match_id);
create index if not exists match_events_player_idx      on public.match_events (player_id, type);
create index if not exists profiles_tournament_idx      on public.profiles (tournament_id, role);
create index if not exists profiles_user_idx            on public.profiles (user_id);
create index if not exists albums_profile_idx           on public.albums (profile_id);


-- ---------------------------------------------------------------------
-- 5. updated_at automático
-- ---------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array['tournaments','groups','teams','players','matches','legends','profiles','albums']
  loop
    execute format('drop trigger if exists trg_touch_%1$s on public.%1$I', t);
    execute format(
      'create trigger trg_touch_%1$s before update on public.%1$I
       for each row execute function public.touch_updated_at()', t);
  end loop;
end $$;


-- ---------------------------------------------------------------------
-- 6. VISTAS — la lógica que hoy corre en el navegador
-- ---------------------------------------------------------------------

-- Partidos con resultado válido. Equivale a matchScoreOk(): en una serie
-- de ida y vuelta hacen falta los CUATRO marcadores.
create or replace view public.v_matches_played
  with (security_invoker = on) as
select m.*,
       case when m.two_legs
            then coalesce(m.score_home,0) + coalesce(m.score_home_leg2,0)
            else coalesce(m.score_home,0) end as agg_home,
       case when m.two_legs
            then coalesce(m.score_away,0) + coalesce(m.score_away_leg2,0)
            else coalesce(m.score_away,0) end as agg_away
from public.matches m
where m.score_home is not null
  and m.score_away is not null
  and (not m.two_legs or (m.score_home_leg2 is not null and m.score_away_leg2 is not null));


-- Tabla de posiciones. Reproduce getGroupStandings():
--   · sólo partidos de grupo con resultado cargado
--   · 3 / 1 / 0
--   · orden por PTS, DG, GF y por último el orden de carga del equipo
-- El desempate por enfrentamiento directo NO está acá: es opcional
-- (format.h2h_tiebreak), se aplica sólo entre los equipos empatados y es
-- iterativo. Si se necesita, va como función aparte.
create or replace view public.v_group_standings
  with (security_invoker = on) as
with jugados as (
  select m.group_id, m.home_team_id as team_id,
         greatest(m.score_home,0) as gf, greatest(m.score_away,0) as gc
  from public.matches m
  where m.phase = 'group'
    and m.score_home is not null and m.score_away is not null
    and m.home_team_id is not null and m.away_team_id is not null
  union all
  select m.group_id, m.away_team_id,
         greatest(m.score_away,0), greatest(m.score_home,0)
  from public.matches m
  where m.phase = 'group'
    and m.score_home is not null and m.score_away is not null
    and m.home_team_id is not null and m.away_team_id is not null
)
select
  t.tournament_id,
  t.group_id,
  t.id                                                             as team_id,
  t.name                                                           as team_name,
  t.short_name,
  count(j.team_id)::int                                            as pj,
  coalesce(sum((j.gf >  j.gc)::int), 0)::int                       as pg,
  coalesce(sum((j.gf =  j.gc)::int), 0)::int                       as pe,
  coalesce(sum((j.gf <  j.gc)::int), 0)::int                       as pp,
  coalesce(sum(j.gf), 0)::int                                      as gf,
  coalesce(sum(j.gc), 0)::int                                      as gc,
  coalesce(sum(j.gf - j.gc), 0)::int                               as dg,
  coalesce(sum(case when j.gf > j.gc then 3
                    when j.gf = j.gc then 1 else 0 end), 0)::int   as pts,
  rank() over (
    partition by t.group_id
    order by coalesce(sum(case when j.gf > j.gc then 3
                               when j.gf = j.gc then 1 else 0 end), 0) desc,
             coalesce(sum(j.gf - j.gc), 0) desc,
             coalesce(sum(j.gf), 0) desc,
             t.sort_order
  )::int                                                           as posicion
from public.teams t
left join jugados j on j.team_id = t.id
group by t.tournament_id, t.group_id, t.id, t.name, t.short_name, t.sort_order;


-- Goleadores.
create or replace view public.v_top_scorers
  with (security_invoker = on) as
select
  p.tournament_id,
  p.id                                        as player_id,
  trim(p.first_name || ' ' || p.last_name)    as player_name,
  p.number,
  p.position,
  t.id                                        as team_id,
  t.name                                      as team_name,
  count(*)::int                               as goals
from public.match_events e
join public.players p on p.id = e.player_id
join public.teams   t on t.id = p.team_id
where e.type = 'goal'
group by p.tournament_id, p.id, p.first_name, p.last_name, p.number, p.position, t.id, t.name;


-- Amarillas y rojas. El orden que usa la app pone primero al más
-- amonestado, con la roja pesando 3 para que no quede debajo de alguien
-- con dos amarillas.
create or replace view public.v_discipline
  with (security_invoker = on) as
select
  p.tournament_id,
  p.id                                        as player_id,
  trim(p.first_name || ' ' || p.last_name)    as player_name,
  t.id                                        as team_id,
  t.name                                      as team_name,
  count(*) filter (where e.type = 'yellow')::int as yellow,
  count(*) filter (where e.type = 'red')::int    as red,
  (count(*) filter (where e.type = 'yellow')
   + count(*) filter (where e.type = 'red') * 3)::int as peso
from public.match_events e
join public.players p on p.id = e.player_id
join public.teams   t on t.id = p.team_id
where e.type in ('yellow','red')
group by p.tournament_id, p.id, p.first_name, p.last_name, t.id, t.name;


-- Suspendidos: acumulación de amarillas y rojas, según el formato del
-- torneo. Es el aviso que la app muestra en la ficha del plantel.
create or replace view public.v_suspensions
  with (security_invoker = on) as
select
  d.tournament_id,
  d.player_id,
  d.player_name,
  d.team_id,
  d.yellow,
  d.red,
  (d.yellow >= tn.yellow_cards_suspension or d.red > 0) as suspendido
from public.v_discipline d
join public.tournaments tn on tn.id = d.tournament_id;


-- Figuras del partido. Sólo cuentan los partidos con resultado cargado:
-- si no, un destacado marcado por error en un partido que después se
-- borra seguiría sumando.
create or replace view public.v_mvp_ranking
  with (security_invoker = on) as
select
  p.tournament_id,
  p.id                                        as player_id,
  trim(p.first_name || ' ' || p.last_name)    as player_name,
  t.id                                        as team_id,
  t.name                                      as team_name,
  count(*)::int                               as veces_figura
from public.v_matches_played m
join public.players p on p.id = m.mvp_player_id
join public.teams   t on t.id = p.team_id
group by p.tournament_id, p.id, p.first_name, p.last_name, t.id, t.name;


-- Partidos jugados y vallas invictas por equipo, contando grupos Y
-- llave, sobre el global de la serie.
create or replace view public.v_team_match_totals
  with (security_invoker = on) as
with lados as (
  select m.tournament_id, m.home_team_id as team_id, m.agg_home as gf, m.agg_away as gc
  from public.v_matches_played m where m.home_team_id is not null
  union all
  select m.tournament_id, m.away_team_id, m.agg_away, m.agg_home
  from public.v_matches_played m where m.away_team_id is not null
)
select
  team_id,
  tournament_id,
  count(*)::int                                as pj_totales,
  count(*) filter (where gc = 0)::int          as vallas_invictas
from lados
group by tournament_id, team_id;


-- ---------------------------------------------------------------------
--  VALOR DE LA FIGURITA
--  Traducción literal de playerRating(). El número no es un adorno:
--  sale de lo que el jugador hizo en ESTE torneo.
--
--  Cuidado con un detalle heredado: el rendimiento del equipo usa los
--  puntos y partidos DE LA FASE DE GRUPOS (computeTeamStats), mientras
--  que el bonus por continuidad usa TODOS los partidos jugados por el
--  equipo. Se replica igual para que el valor no cambie al migrar.
-- ---------------------------------------------------------------------
create or replace view public.v_player_rating
  with (security_invoker = on) as
with base as (
  select
    p.tournament_id,
    p.id as player_id,
    p.team_id,
    p.position,
    case p.position when 'ARQ' then 62 when 'DEF' then 63 else 64 end::numeric as r_base,
    case p.position when 'ARQ' then 9   when 'DEF' then 5.5 when 'MED' then 4   else 3.2 end::numeric as r_gol,
    case p.position when 'ARQ' then 5   when 'DEF' then 4   when 'MED' then 3.4 else 2.6 end::numeric as r_asis
  from public.players p
),
ev as (
  select e.player_id,
         count(*) filter (where e.type = 'goal')::int   as goles,
         count(*) filter (where e.type = 'assist')::int as asistencias,
         count(*) filter (where e.type = 'yellow')::int as amarillas,
         count(*) filter (where e.type = 'red')::int    as rojas
  from public.match_events e
  group by e.player_id
),
calc as (
  select
    b.tournament_id,
    b.player_id,
    b.position,
    coalesce(tot.pj_totales, 0)                        as pj_totales,
    b.r_base
      + coalesce(ev.goles,0)       * b.r_gol
      + coalesce(ev.asistencias,0) * b.r_asis
      - coalesce(ev.amarillas,0)   * 1.2
      - coalesce(ev.rojas,0)       * 4
      + case when b.position in ('ARQ','DEF')
             then coalesce(tot.vallas_invictas,0) * 2.6 else 0 end
      -- el equipo arrastra a todo el plantel, pero poco: 6 puntos entre
      -- ganar todo y perder todo
      + (coalesce(st.pts,0)::numeric / greatest(1, coalesce(st.pj,0) * 3)) * 6
      -- continuidad
      + least(coalesce(tot.pj_totales,0), 6) * 0.5
      -- figura del partido: premia al que rindió aunque no haya hecho el gol
      + coalesce(mvp.veces_figura,0) * 2.2                       as ovr_crudo
  from base b
  left join ev  on ev.player_id = b.player_id
  left join public.v_team_match_totals tot on tot.team_id = b.team_id
  left join public.v_group_standings   st  on st.team_id  = b.team_id
  left join public.v_mvp_ranking       mvp on mvp.player_id = b.player_id
)
select
  tournament_id,
  player_id,
  -- sin partidos jugados nadie es leyenda: todos quedan en su base
  case when pj_totales = 0
       then round(case position when 'ARQ' then 62 when 'DEF' then 63 else 64 end)
       else greatest(45, least(99, round(ovr_crudo)))
  end::int as ovr,
  case
    when pj_totales = 0 then 'comun'
    when greatest(45, least(99, round(ovr_crudo))) >= 84 then 'dorada'
    when greatest(45, least(99, round(ovr_crudo))) >= 74 then 'plata'
    else 'comun'
  end as tier
from calc;


-- Progreso del álbum de cada persona.
create or replace view public.v_album_progress
  with (security_invoker = on) as
select
  a.id                                             as album_id,
  a.tournament_id,
  a.profile_id,
  pr.display_name,
  count(s.sticker_number)::int                     as figuritas_distintas,
  coalesce(sum(s.copies), 0)::int                  as figuritas_totales,
  coalesce(sum(greatest(s.copies - 1, 0)), 0)::int as repetidas
from public.albums a
join public.profiles pr on pr.id = a.profile_id
left join public.album_stickers s on s.album_id = a.id
group by a.id, a.tournament_id, a.profile_id, pr.display_name;


-- ---------------------------------------------------------------------
-- 7. PERMISOS — las tres funciones que usan todas las políticas
-- ---------------------------------------------------------------------

-- security definer para que la política pueda leer profiles sin caer en
-- una recursión de RLS contra la propia tabla.
create or replace function public.es_admin(p_tournament uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles
    where user_id = auth.uid()
      and tournament_id = p_tournament
      and role = 'admin'
  );
$$;

create or replace function public.es_capitan_de(p_team uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles
    where user_id = auth.uid()
      and role = 'capitan'
      and team_id = p_team
  );
$$;

-- ¿este perfil es mío?
create or replace function public.es_mi_perfil(p_profile uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles
    where id = p_profile and user_id = auth.uid()
  );
$$;


-- ---------------------------------------------------------------------
-- 8. RLS
--    El torneo se mira libremente —la app se proyecta al costado de la
--    cancha— así que la lectura es pública. Escribir es otra cosa.
-- ---------------------------------------------------------------------
alter table public.tournaments    enable row level security;
alter table public.groups         enable row level security;
alter table public.teams          enable row level security;
alter table public.players        enable row level security;
alter table public.matches        enable row level security;
alter table public.match_events   enable row level security;
alter table public.legends        enable row level security;
alter table public.profiles       enable row level security;
alter table public.albums         enable row level security;
alter table public.album_stickers enable row level security;

-- --- lectura pública de todo lo que es "el torneo" -------------------
do $$
declare t text;
begin
  foreach t in array array['tournaments','groups','teams','players','matches','match_events','legends']
  loop
    execute format('drop policy if exists "lectura publica" on public.%I', t);
    execute format(
      'create policy "lectura publica" on public.%I for select to anon, authenticated using (true)', t);
  end loop;
end $$;

-- --- escritura: sólo administrador -----------------------------------
drop policy if exists "admin escribe torneo" on public.tournaments;
create policy "admin escribe torneo" on public.tournaments
  for all to authenticated
  using (public.es_admin(id)) with check (public.es_admin(id));

drop policy if exists "admin escribe grupos" on public.groups;
create policy "admin escribe grupos" on public.groups
  for all to authenticated
  using (public.es_admin(tournament_id)) with check (public.es_admin(tournament_id));

drop policy if exists "admin escribe equipos" on public.teams;
create policy "admin escribe equipos" on public.teams
  for all to authenticated
  using (public.es_admin(tournament_id)) with check (public.es_admin(tournament_id));

drop policy if exists "admin escribe partidos" on public.matches;
create policy "admin escribe partidos" on public.matches
  for all to authenticated
  using (public.es_admin(tournament_id)) with check (public.es_admin(tournament_id));

drop policy if exists "admin escribe leyendas" on public.legends;
create policy "admin escribe leyendas" on public.legends
  for all to authenticated
  using (public.es_admin(tournament_id)) with check (public.es_admin(tournament_id));

-- Los eventos cuelgan del partido, así que el permiso se mira en el
-- partido al que pertenecen.
drop policy if exists "admin escribe eventos" on public.match_events;
create policy "admin escribe eventos" on public.match_events
  for all to authenticated
  using (exists (select 1 from public.matches m
                 where m.id = match_id and public.es_admin(m.tournament_id)))
  with check (exists (select 1 from public.matches m
                      where m.id = match_id and public.es_admin(m.tournament_id)));

-- --- jugadores: el admin, o el capitán DE SU equipo -------------------
-- Es la misma regla que puedeEditarEquipo() en la app. Acá, además, no
-- se puede saltear desde la consola del navegador.
drop policy if exists "plantel propio o admin" on public.players;
create policy "plantel propio o admin" on public.players
  for all to authenticated
  using      (public.es_admin(tournament_id) or public.es_capitan_de(team_id))
  with check (public.es_admin(tournament_id) or public.es_capitan_de(team_id));

-- --- perfiles ---------------------------------------------------------
-- Se leen todos: la pantalla de "¿Quién sos?" necesita listarlos.
drop policy if exists "perfiles visibles" on public.profiles;
create policy "perfiles visibles" on public.profiles
  for select to anon, authenticated using (true);

drop policy if exists "cada uno edita su perfil" on public.profiles;
create policy "cada uno edita su perfil" on public.profiles
  for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Crear capitanes y administradores es tarea del admin.
drop policy if exists "admin gestiona perfiles" on public.profiles;
create policy "admin gestiona perfiles" on public.profiles
  for all to authenticated
  using (public.es_admin(tournament_id)) with check (public.es_admin(tournament_id));

-- --- álbum: cada uno con el suyo -------------------------------------
drop policy if exists "album propio" on public.albums;
create policy "album propio" on public.albums
  for all to authenticated
  using      (public.es_mi_perfil(profile_id) or public.es_admin(tournament_id))
  with check (public.es_mi_perfil(profile_id) or public.es_admin(tournament_id));

drop policy if exists "figuritas propias" on public.album_stickers;
create policy "figuritas propias" on public.album_stickers
  for all to authenticated
  using (exists (select 1 from public.albums a
                 where a.id = album_id
                   and (public.es_mi_perfil(a.profile_id) or public.es_admin(a.tournament_id))))
  with check (exists (select 1 from public.albums a
                      where a.id = album_id
                        and (public.es_mi_perfil(a.profile_id) or public.es_admin(a.tournament_id))));


-- =====================================================================
-- 9. SORTEO Y FIXTURE OFICIALES
--
--    Los datos son los de los dos afiches del torneo:
--      · "Sorteo Oficial · Fase de Grupos"        → equipos, países, capitanes
--      · "Fixture de Enfrentamientos · Fase de Grupos" → los 12 partidos
--    y coinciden exactamente con lo que ya tiene cargado la app.
--
--    Se puede correr las veces que haga falta: si el torneo ya existe,
--    actualiza en lugar de duplicar (upsert por legacy_id).
-- =====================================================================
do $$
declare
  v_torneo uuid;
  v_ga     uuid;
  v_gb     uuid;
  r        record;
  v_home   uuid;
  v_away   uuid;
begin
  ------------------------------------------------------------------ torneo
  select id into v_torneo from public.tournaments where legacy_id = 'alas-torneo-v3';
  if v_torneo is null then
    insert into public.tournaments (name, subtitle, season, legacy_id)
    values ('Mundial ALAS 2026', 'Fixture oficial · Copa interna', '2026', 'alas-torneo-v3')
    returning id into v_torneo;
  end if;

  ------------------------------------------------------------------ grupos
  insert into public.groups (tournament_id, name, sort_order, legacy_id)
  values (v_torneo, 'Grupo A', 0, 'g1'), (v_torneo, 'Grupo B', 1, 'g2')
  on conflict (tournament_id, legacy_id) do update
    set name = excluded.name, sort_order = excluded.sort_order;

  select id into v_ga from public.groups where tournament_id = v_torneo and legacy_id = 'g1';
  select id into v_gb from public.groups where tournament_id = v_torneo and legacy_id = 'g2';

  -- La primera versión de este archivo sembraba ocho equipos de relleno
  -- con estos mismos nombres. Como el nombre es único por torneo, esas
  -- filas chocarían con las de abajo. Se limpian, pero SÓLO si están
  -- vacías: si alguien ya les cargó plantel o las metió en un partido,
  -- se dejan como están y el error avisa que hay que revisarlo a mano.
  delete from public.teams t
   where t.tournament_id = v_torneo
     and t.legacy_id in ('t1','t2','t3','t4','t5','t6','t7','t8')
     and not exists (select 1 from public.players p where p.team_id = t.id)
     and not exists (select 1 from public.matches m
                      where m.home_team_id = t.id or m.away_team_id = t.id);

  ------------------------------------------------------------------ equipos
  -- Los colores son los de la bandera de cada país, que es lo que define
  -- el fondo de la figurita en el álbum.
  for r in
    select * from (values
      ('t-produccion',   'Producción',            'Producción',     'py', 'Paraguay',   'Daniel Gimenez',     'g1', '#d52b1e', '#0038a8', 0),
      ('t-deposito',     'Depósito',              'Depósito',       'de', 'Alemania',   'Carlos Versa',       'g1', '#1a1a1a', '#ffce00', 1),
      ('t-picking',      'Picking / Empaque',     'Picking',        'pt', 'Portugal',   'Rafael Ovelar',      'g1', '#006600', '#ff0000', 2),
      ('t-distlocal',    'Distribución Local',    'Dist. Local',    'no', 'Noruega',    'Juan Marcos Aveiro', 'g1', '#ba0c2f', '#00205b', 3),
      ('t-ventas',       'Ventas Externas',       'Ventas Ext.',    'br', 'Brasil',     'Raul Caballero',     'g2', '#009b3a', '#fedf00', 4),
      ('t-admin',        'Admin / Logística',     'Admin/Log.',     'en', 'Inglaterra', 'Adrian Gomez',       'g2', '#cf142b', '#012169', 5),
      ('t-distinterior', 'Distribución Interior', 'Dist. Interior', 'jp', 'Japón',      'Enrique Arza',       'g2', '#bc002d', '#ffffff', 6),
      ('t-fabrica',      'Fábrica',               'Fábrica',        'be', 'Bélgica',    'Victor Marecos',     'g2', '#f0b800', '#ef3340', 7)
    ) as t(legacy_id, name, short_name, country, country_name, captain_name, grupo, c1, c2, orden)
  loop
    insert into public.teams
      (tournament_id, group_id, name, short_name, country, country_name,
       captain_name, color_primary, color_secondary, sort_order, legacy_id)
    values
      (v_torneo,
       case r.grupo when 'g1' then v_ga else v_gb end,
       r.name, r.short_name, r.country, r.country_name,
       r.captain_name, r.c1, r.c2, r.orden, r.legacy_id)
    on conflict (tournament_id, legacy_id) do update set
      group_id        = excluded.group_id,
      name            = excluded.name,
      short_name      = excluded.short_name,
      country         = excluded.country,
      country_name    = excluded.country_name,
      captain_name    = excluded.captain_name,
      color_primary   = excluded.color_primary,
      color_secondary = excluded.color_secondary,
      sort_order      = excluded.sort_order;
  end loop;

  ------------------------------------------------------------------ partidos
  -- Fixture EXACTO del afiche. Sedes: las dos primeras fechas en el
  -- Campamento Ita y la tercera en el Club de Oficiales.
  for r in
    select * from (values
      ('m-a1', 't-produccion',   't-deposito',     'g1', 1, date '2026-08-22', 'Campamento Ita'),
      ('m-a2', 't-picking',      't-distlocal',    'g1', 1, date '2026-08-22', 'Campamento Ita'),
      ('m-a3', 't-produccion',   't-picking',      'g1', 2, date '2026-08-23', 'Campamento Ita'),
      ('m-a4', 't-deposito',     't-distlocal',    'g1', 2, date '2026-08-23', 'Campamento Ita'),
      ('m-a5', 't-produccion',   't-distlocal',    'g1', 3, date '2026-08-28', 'Club de Oficiales Policía Nacional'),
      ('m-a6', 't-deposito',     't-picking',      'g1', 3, date '2026-08-28', 'Club de Oficiales Policía Nacional'),
      ('m-b1', 't-ventas',       't-admin',        'g2', 1, date '2026-08-22', 'Campamento Ita'),
      ('m-b2', 't-distinterior', 't-fabrica',      'g2', 1, date '2026-08-22', 'Campamento Ita'),
      ('m-b3', 't-ventas',       't-distinterior', 'g2', 2, date '2026-08-23', 'Campamento Ita'),
      ('m-b4', 't-admin',        't-fabrica',      'g2', 2, date '2026-08-23', 'Campamento Ita'),
      ('m-b5', 't-ventas',       't-fabrica',      'g2', 3, date '2026-08-28', 'Club de Oficiales Policía Nacional'),
      ('m-b6', 't-admin',        't-distinterior', 'g2', 3, date '2026-08-28', 'Club de Oficiales Policía Nacional')
    ) as m(legacy_id, local, visitante, grupo, fecha, dia, sede)
  loop
    select id into v_home from public.teams where tournament_id = v_torneo and legacy_id = r.local;
    select id into v_away from public.teams where tournament_id = v_torneo and legacy_id = r.visitante;

    insert into public.matches
      (tournament_id, phase, group_id, round,
       home_source, home_team_id, away_source, away_team_id,
       match_date, venue, status, legacy_id)
    values
      (v_torneo, 'group',
       case r.grupo when 'g1' then v_ga else v_gb end,
       r.fecha,
       'team', v_home, 'team', v_away,
       r.dia, r.sede, 'scheduled', r.legacy_id)
    on conflict (tournament_id, legacy_id) do update set
      group_id     = excluded.group_id,
      round        = excluded.round,
      home_team_id = excluded.home_team_id,
      away_team_id = excluded.away_team_id,
      match_date   = excluded.match_date,
      venue        = excluded.venue;
      -- a propósito NO se pisan los marcadores ni el estado: si el
      -- partido ya se jugó, volver a correr la semilla no lo borra
  end loop;

  raise notice 'Torneo % — 2 grupos, 8 equipos y 12 partidos cargados.', v_torneo;
end $$;


-- Control rápido de lo que quedó cargado.
-- select g.name as grupo, t.sort_order + 1 as nro, t.name, t.country_name, t.captain_name
--   from public.teams t join public.groups g on g.id = t.group_id
--  order by g.sort_order, t.sort_order;
--
-- select g.name as grupo, m.round as fecha, m.match_date, m.venue,
--        h.name as local, a.name as visitante
--   from public.matches m
--   join public.groups g on g.id = m.group_id
--   join public.teams  h on h.id = m.home_team_id
--   join public.teams  a on a.id = m.away_team_id
--  order by g.sort_order, m.round, h.sort_order;


-- =====================================================================
--  FOTOS
--  Los escudos, la foto grupal y las caras de las figuritas hoy viajan
--  como data URI dentro del JSON, y por eso el archivo pesa lo que pesa.
--  En Supabase van a Storage y en la tabla queda sólo la ruta.
--  Crear el bucket una vez (Storage → New bucket → "media", público) y
--  guardar en logo_path / photo_path algo como 'teams/<uuid>.webp'.
--  La URL se arma con:
--     supabase.storage.from('media').getPublicUrl(photo_path)
-- =====================================================================
