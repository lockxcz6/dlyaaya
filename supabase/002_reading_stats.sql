-- Run AFTER schema.sql. Safe to run this migration again.
create table if not exists public.reading_sessions (
 book_id text not null references public.book_owners(book_id) on delete cascade,
 session_id uuid primary key, token uuid not null, visitor_id uuid not null,
 opened_at timestamptz not null default now(), last_seen timestamptz not null default now(),
 active_seconds integer not null default 0, device text not null,
 position jsonb
);
alter table public.reading_sessions enable row level security;
revoke all on public.reading_sessions from anon, authenticated;
grant select(book_id,session_id,visitor_id,opened_at,last_seen,active_seconds,device,position) on public.reading_sessions to authenticated;
grant delete on public.reading_sessions to authenticated;
drop policy if exists "owner reads reading sessions" on public.reading_sessions;
create policy "owner reads reading sessions" on public.reading_sessions for select to authenticated
using(exists(select 1 from public.book_owners o where o.book_id=reading_sessions.book_id and o.owner_id=auth.uid()));
drop policy if exists "owner deletes reading sessions" on public.reading_sessions;
create policy "owner deletes reading sessions" on public.reading_sessions for delete to authenticated
using(exists(select 1 from public.book_owners o where o.book_id=reading_sessions.book_id and o.owner_id=auth.uid()));
create or replace function public.record_reading(p_book_id text,p_session uuid,p_token uuid,p_visitor uuid,p_position jsonb,p_active integer,p_device text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.publications where book_id=p_book_id) then return; end if;
 if p_session is null or p_token is null or p_visitor is null or p_active is null or p_device is null or length(p_device)>40 or octet_length(coalesce(p_position,'{}'::jsonb)::text)>2048 then raise exception 'Invalid reading event'; end if;
 -- Session token permits updating only that random session. Reader cannot read any rows.
 insert into public.reading_sessions(book_id,session_id,token,visitor_id,device,position,active_seconds)
 values(p_book_id,p_session,p_token,p_visitor,p_device,p_position,0)
 on conflict(session_id) do update set
 position=excluded.position,last_seen=now(),
 active_seconds=greatest(public.reading_sessions.active_seconds,least(p_active,public.reading_sessions.active_seconds+greatest(0,extract(epoch from(now()-public.reading_sessions.last_seen))::integer)+2))
 where public.reading_sessions.token=p_token and public.reading_sessions.book_id=p_book_id and public.reading_sessions.visitor_id=p_visitor;
end $$;
revoke all on function public.record_reading(text,uuid,uuid,uuid,jsonb,integer,text) from public;
grant execute on function public.record_reading(text,uuid,uuid,uuid,jsonb,integer,text) to anon,authenticated;
