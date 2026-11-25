-- 24/11/2026 · Empiece Ya: PB23 trae un premio nuevo y cada carga pasa sola a Premios.
-- Aplicado con execute_sql el 24/11/2026. Copia para el repo (regla 7 de claude/plataforma.md).

-- 1 · El viaje del PB23 es a Guanacaste (antes Miami). Entra al catálogo como «viaje»,
--     así el portal lo cuenta en «Premio viaje» y el Nivel Cero lo toma como su nivel de viaje
--     (ver renaware-nivel-cero/sql/20261124_nivel_viaje.sql).
insert into public.eya_items (item, categoria, orden)
select 'Viaje a Guanacaste', 'viaje', 11
where not exists (select 1 from public.eya_items where item = 'Viaje a Guanacaste');

insert into public.eya_item_alias (patron, item, prioridad)
select 'guanacaste', 'Viaje a Guanacaste', 20
where not exists (select 1 from public.eya_item_alias where patron = 'guanacaste');

-- 2 · Premios (repo Premios-equipo) solo traía el Empiece Ya con su botón
--     «Traer ganadores de ¡Empiece Ya!»; nadie lo apretó desde el 20/10 y se quedó en el PB20.
--     Ahora pr_sincronizar_eya() (función de Premios):
--       - solo trae desde el PB10 de 2026 (lo que Premios ya llevaba; lo anterior llenaría
--         la lista de entregas con premios viejos),
--       - marca «preliminar» lo que es preliminar en eya_periodos y sube a «final» cuando
--         llega el oficial (nunca baja de final a preliminar),
--       - no se cae si el Empiece Ya trae dos filas con la misma clave.
create or replace function public.pr_sincronizar_eya()
 returns table(nuevos integer, total_eya integer)
 language plpgsql
as $function$
declare
  antes integer;
  despues integer;
  -- Premios lleva el Empiece Ya desde el PB10 de 2026 (lo que se trajo el 20/10/2026).
  -- Lo anterior no entra solo: llenaría la lista de entregas con premios viejos.
  desde constant date := date '2026-05-13';
begin
  select count(*) into antes from pr_premios where programa = 'Programa ¡Empiece Ya!';

  with jefatura as (
    -- cada división tiene un élite y una organización; se toman del dato más
    -- reciente que ya exista en el registro
    select distinct on (div) div, elite, organizacion
      from pr_premios
     where div is not null and organizacion is not null
     order by div, periodo_fin desc
  ), fuente as (
    select distinct on (x.clave) x.*
      from (select substr(md5('Programa ¡Empiece Ya!|' || e.codigo || '|' || e.premio ||
                              '||' || pe.fecha_cierre::text), 1, 16) as clave,
                   -- preliminar mientras el cierre lo sea en Empiece Ya; final cuando llega el oficial
                   case when pe.estado = 'Preliminar' then 'preliminar' else 'final' end as tipo,
                   e.codigo, e.nombre, e.division, e.premio, pe.fecha_cierre, e.pb
              from eya_premios e
              join eya_periodos pe on pe.anio = e.anio and pe.pb = e.pb
             where pe.fecha_cierre is not null and pe.fecha_cierre >= desde) x
     order by x.clave
  )
  insert into pr_premios (
    clave, programa, tipo, codigo, nombre, div, elite, organizacion,
    cantidad, premio, nivel, periodo_fin, periodo_num, origen)
  select f.clave, 'Programa ¡Empiece Ya!', f.tipo, f.codigo, f.nombre, f.division,
         j.elite, j.organizacion, 1, f.premio, null, f.fecha_cierre, f.pb, 'resultado'
    from fuente f
    left join jefatura j on j.div = f.division
  on conflict (clave) do update
     set tipo = 'final', actualizado_en = now()
   where pr_premios.tipo = 'preliminar' and excluded.tipo = 'final';

  select count(*) into despues from pr_premios where programa = 'Programa ¡Empiece Ya!';
  return query select (despues - antes)::integer, despues::integer;
end $function$;

-- 3 · Cada carga del Empiece Ya (eya_cargar_pb_interno inserta primero el período y luego
--     las filas) dispara la sincronización una vez por sentencia. Si Premios falla, la carga
--     del Empiece Ya sigue y queda un warning en el log.
create or replace function public.eya_tg_a_premios()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  -- Cada carga del Empiece Ya pasa sola a Premios (lo mismo que el botón
  -- «Traer ganadores de ¡Empiece Ya!»). Si Premios falla, la carga sigue igual.
  begin
    perform public.pr_sincronizar_eya();
  exception when others then
    raise warning 'Premios no se actualizó con el Empiece Ya: %', sqlerrm;
  end;
  return null;
end $function$;

revoke all on function public.eya_tg_a_premios() from public, anon, authenticated;

create or replace trigger eya_premios_a_premios
  after insert on public.eya_premios
  for each statement execute function public.eya_tg_a_premios();

comment on function public.pr_sincronizar_eya() is 'Copia los ganadores del Empiece Ya (eya_premios) a Premios (pr_premios) desde el PB10 de 2026: preliminar mientras el cierre lo sea en eya_periodos, final cuando llega el oficial (nunca baja de final a preliminar). Corre sola en cada carga (disparador eya_premios_a_premios) y también con el botón «Traer ganadores de ¡Empiece Ya!» de Premios. Lo declarado lo concilia la página de Premios al abrir.';
comment on trigger eya_premios_a_premios on public.eya_premios is 'Cada carga del Empiece Ya pasa sola a Premios (pr_sincronizar_eya). Si Premios falla, la carga del Empiece Ya sigue y queda un warning.';

-- 4 · Puesta al día (una vez): trajo el PB21, PB22 y PB23 (306 filas, preliminares).
-- select * from public.pr_sincronizar_eya();
