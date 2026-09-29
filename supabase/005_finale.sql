-- Final states replace actual resource deletion. Apply after 004.
drop function if exists public.purge_book_data(text);
create table if not exists public.reader_final_state (
 book_id text primary key references public.book_owners(book_id) on delete cascade,
 choice text not null default 'not_chosen' check(choice in ('not_chosen','closed','kept')),
 access_mode text not null default 'normal' check(access_mode in ('normal','maintenance')),
 chosen_at timestamptz, snapshot jsonb, epoch integer not null default 0
);
create table if not exists public.finale_reader_keys(book_id text primary key references public.book_owners(book_id) on delete cascade,key_hash text not null);
create table if not exists public.finale_admin_audit(id bigint generated always as identity primary key,book_id text not null references public.book_owners(book_id) on delete cascade,admin_id uuid,operation text not null,previous_state jsonb,new_state jsonb,created_at timestamptz not null default now());
alter table public.reader_final_state enable row level security;
alter table public.finale_reader_keys enable row level security;
alter table public.finale_admin_audit enable row level security;
revoke all on public.reader_final_state,public.finale_reader_keys,public.finale_admin_audit from anon,authenticated;
grant select on public.reader_final_state,public.finale_admin_audit to authenticated;
drop policy if exists "author sees final state" on public.reader_final_state;
create policy "author sees final state" on public.reader_final_state for select to authenticated using(exists(select 1 from public.book_owners o where o.book_id=reader_final_state.book_id and o.owner_id=auth.uid()));
drop policy if exists "author sees finale audit" on public.finale_admin_audit;
create policy "author sees finale audit" on public.finale_admin_audit for select to authenticated using(exists(select 1 from public.book_owners o where o.book_id=finale_admin_audit.book_id and o.owner_id=auth.uid()));
create or replace function public.get_finale_state(p_book_id text) returns jsonb language sql security definer set search_path='' as $$
 select coalesce((select jsonb_build_object('choice',s.choice,'chosen_at',s.chosen_at,'access_mode',s.access_mode,'epoch',s.epoch,'snapshot',s.snapshot) from public.reader_final_state s where s.book_id=p_book_id),'{"choice":"not_chosen","access_mode":"normal","epoch":0}'::jsonb)
$$;
create or replace function public.choose_finale(p_book_id text,p_choice text,p_key_hash text,p_epoch integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.reader_final_state; p jsonb; cfg jsonb;
begin
 if p_choice is null or p_choice not in ('closed','kept') then raise exception 'Недопустимая ветка'; end if;
 perform 1 from public.book_owners where book_id=p_book_id for update;
 if not exists(select 1 from public.finale_reader_keys where book_id=p_book_id and key_hash=p_key_hash) then raise exception 'Нужна читательская ссылка с правом выбора. Автор может создать её в разделе Финал.'; end if;
 insert into public.reader_final_state(book_id) values(p_book_id) on conflict do nothing;
 select * into s from public.reader_final_state where book_id=p_book_id for update;
 if s.choice<>'not_chosen' then return public.get_finale_state(p_book_id)||'{"already_chosen":true}'::jsonb; end if;
 if p_epoch is null or p_epoch<>s.epoch or s.access_mode='maintenance' then raise exception 'Настройки доступа изменились. Открой книгу заново.'; end if;
 select payload into p from public.publications where book_id=p_book_id; cfg:=p->'finale';
 if cfg is null or coalesce((cfg->>'enabled')::boolean,false)=false or coalesce((cfg->>'choicesEnabled')::boolean,false)=false or coalesce((cfg->>(p_choice||'Enabled'))::boolean,false)=false then raise exception 'Этот вариант сейчас недоступен'; end if;
 update public.reader_final_state set choice=p_choice,chosen_at=now(),snapshot=jsonb_build_object('config',cfg,'assets',p->'assets'),epoch=epoch+1 where book_id=p_book_id;
 insert into public.finale_admin_audit(book_id,operation,previous_state,new_state) values(p_book_id,'reader_choice',to_jsonb(s),jsonb_build_object('choice',p_choice));
 return public.get_finale_state(p_book_id);
end $$;
create or replace function public.set_finale_reader_key(p_book_id text,p_hash text) returns void language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.book_owners where book_id=p_book_id and owner_id=auth.uid() for update;
 if not found then raise exception 'Только автор'; end if;
 if p_hash is null or p_hash !~ '^[a-f0-9]{64}$' then raise exception 'Некорректный хеш'; end if;
 insert into public.finale_reader_keys(book_id,key_hash) values(p_book_id,p_hash) on conflict(book_id) do update set key_hash=excluded.key_hash;
 insert into public.finale_admin_audit(book_id,admin_id,operation) values(p_book_id,auth.uid(),'reader_link_changed');
end $$;
create or replace function public.admin_finale_state(p_book_id text,p_choice text,p_access text,p_confirm text) returns jsonb language plpgsql security definer set search_path='' as $$
declare old public.reader_final_state; p jsonb;
begin
 perform 1 from public.book_owners where book_id=p_book_id and owner_id=auth.uid() for update;
 if not found then raise exception 'Только автор'; end if;
 if p_confirm is distinct from 'ИЗМЕНИТЬ' or p_choice not in ('not_chosen','closed','kept') or p_access not in ('normal','maintenance') then raise exception 'Нужно отдельное подтверждение'; end if;
 insert into public.reader_final_state(book_id) values(p_book_id) on conflict do nothing;
 select * into old from public.reader_final_state where book_id=p_book_id for update;
 select payload into p from public.publications where book_id=p_book_id;
 update public.reader_final_state set choice=p_choice,access_mode=p_access,epoch=epoch+1,chosen_at=case when p_choice='not_chosen' then null else now() end,snapshot=case when p_choice='not_chosen' then null else jsonb_build_object('config',p->'finale','assets',p->'assets') end where book_id=p_book_id;
 insert into public.finale_admin_audit(book_id,admin_id,operation,previous_state,new_state) values(p_book_id,auth.uid(),'admin_state_change',to_jsonb(old),public.get_finale_state(p_book_id));
 return public.get_finale_state(p_book_id);
end $$;
revoke all on function public.get_finale_state(text),public.choose_finale(text,text,text,integer),public.set_finale_reader_key(text,text),public.admin_finale_state(text,text,text,text) from public;
grant execute on function public.get_finale_state(text),public.choose_finale(text,text,text,integer) to anon,authenticated;
grant execute on function public.set_finale_reader_key(text,text),public.admin_finale_state(text,text,text,text) to authenticated;
