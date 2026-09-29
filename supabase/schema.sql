-- Apply once in Supabase SQL Editor. Then assign the author's auth.users UUID.
create table if not exists public.book_owners (
 book_id text primary key, owner_id uuid not null references auth.users(id)
);
alter table public.book_owners enable row level security;
create policy "author sees own ownership" on public.book_owners for select to authenticated using (owner_id=auth.uid());
create table if not exists public.publications (
 book_id text primary key references public.book_owners(book_id), version integer not null default 0,
 payload jsonb not null, updated_at timestamptz not null default now()
);
create table if not exists public.drafts (
 book_id text primary key references public.book_owners(book_id), base_version integer not null, revision integer not null default 0,
 payload jsonb not null, updated_at timestamptz not null default now()
);
create table if not exists public.revisions (
 id bigint generated always as identity primary key, book_id text not null references public.book_owners(book_id),
 version integer not null, payload jsonb not null, created_at timestamptz not null default now(), unique(book_id,version)
);
alter table public.publications enable row level security;
alter table public.drafts enable row level security;
alter table public.revisions enable row level security;
create policy "read published book" on public.publications for select to anon,authenticated using (true);
create policy "author reads drafts" on public.drafts for select to authenticated using (exists(select 1 from public.book_owners o where o.book_id=drafts.book_id and o.owner_id=auth.uid()));
create policy "author deletes own draft" on public.drafts for delete to authenticated using (exists(select 1 from public.book_owners o where o.book_id=drafts.book_id and o.owner_id=auth.uid()));
create policy "author reads revisions" on public.revisions for select to authenticated using (exists(select 1 from public.book_owners o where o.book_id=revisions.book_id and o.owner_id=auth.uid()));
-- Mutations only through RPCs. Locks serialize publication and stale-version checks.
create or replace function public.publish_book(p_book_id text,p_expected integer,p_payload jsonb)
returns integer language plpgsql security definer set search_path=public as $$
declare v integer;
begin
 perform 1 from book_owners where book_id=p_book_id and owner_id=auth.uid() for update;
 if not found then raise exception 'Только автор может публиковать книгу'; end if;
 select version into v from publications where book_id=p_book_id;
 v:=coalesce(v,0);
 if v<>p_expected then raise exception 'Есть более свежая версия. Сохраните копию черновика и обновите книгу.'; end if;
 if coalesce(jsonb_typeof(p_payload->'chapters'),'null')<>'array' or jsonb_array_length(p_payload->'chapters')<1 then raise exception 'Пустая книга'; end if;
 v:=v+1;
 insert into publications(book_id,version,payload) values(p_book_id,v,p_payload)
 on conflict(book_id) do update set version=excluded.version,payload=excluded.payload,updated_at=now();
 insert into revisions(book_id,version,payload) values(p_book_id,v,p_payload);
 delete from drafts where book_id=p_book_id;
 return v;
end $$;
create or replace function public.save_draft(p_book_id text,p_expected integer,p_draft_expected integer,p_payload jsonb)
returns integer language plpgsql security definer set search_path=public as $$
declare v integer; d integer;
begin
 perform 1 from book_owners where book_id=p_book_id and owner_id=auth.uid() for update;
 if not found then raise exception 'Только автор может сохранять черновик'; end if;
 select version into v from publications where book_id=p_book_id;
 if coalesce(v,0)<>p_expected then raise exception 'Есть более свежая опубликованная версия'; end if;
 select revision into d from drafts where book_id=p_book_id;
 if coalesce(d,0)<>p_draft_expected then raise exception 'Черновик изменён с другого устройства. Сначала сохраните резервную копию.'; end if;
 d:=coalesce(d,0)+1;
 insert into drafts(book_id,base_version,revision,payload) values(p_book_id,p_expected,d,p_payload)
 on conflict(book_id) do update set payload=excluded.payload,revision=excluded.revision,base_version=excluded.base_version,updated_at=now();
 return d;
end $$;
revoke all on function public.publish_book(text,integer,jsonb) from public,anon;
revoke all on function public.save_draft(text,integer,integer,jsonb) from public,anon;
grant execute on function public.publish_book(text,integer,jsonb) to authenticated;
grant execute on function public.save_draft(text,integer,integer,jsonb) to authenticated;
grant select on public.publications to anon,authenticated;
grant select on public.book_owners,public.drafts,public.revisions to authenticated;
grant delete on public.drafts to authenticated;
-- Only assigned/published files are copied here. Draft originals use the private bucket below.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('book-published','book-published',true,20971520,array['image/png','image/jpeg','image/webp','image/gif','audio/mpeg','audio/mp3','audio/wav','audio/x-wav','audio/ogg','audio/opus','audio/mp4','audio/x-m4a','audio/webm','video/mp4','video/webm','video/quicktime'])
on conflict(id) do nothing;
create policy "author uploads publication files" on storage.objects for insert to authenticated
with check(bucket_id='book-published' and (storage.foldername(name))[1]=auth.uid()::text and exists(select 1 from public.book_owners where owner_id=auth.uid()));
create policy "author reads own publication files" on storage.objects for select to authenticated
using(bucket_id='book-published' and (storage.foldername(name))[1]=auth.uid()::text and exists(select 1 from public.book_owners where owner_id=auth.uid()));
create policy "author updates own publication files" on storage.objects for update to authenticated
using(bucket_id='book-published' and (storage.foldername(name))[1]=auth.uid()::text and exists(select 1 from public.book_owners where owner_id=auth.uid()))
with check(bucket_id='book-published' and (storage.foldername(name))[1]=auth.uid()::text and exists(select 1 from public.book_owners where owner_id=auth.uid()));

insert into storage.buckets(id,name,public,file_size_limit)
values('book-drafts','book-drafts',false,20971520) on conflict(id) do nothing;
create policy "author stores private originals" on storage.objects for insert to authenticated
with check(bucket_id='book-drafts' and (storage.foldername(name))[1]=auth.uid()::text and exists(select 1 from public.book_owners where owner_id=auth.uid()));
create policy "author reads private originals" on storage.objects for select to authenticated
using(bucket_id='book-drafts' and (storage.foldername(name))[1]=auth.uid()::text and exists(select 1 from public.book_owners where owner_id=auth.uid()));
create policy "author updates private originals" on storage.objects for update to authenticated
using(bucket_id='book-drafts' and (storage.foldername(name))[1]=auth.uid()::text and exists(select 1 from public.book_owners where owner_id=auth.uid()))
with check(bucket_id='book-drafts' and (storage.foldername(name))[1]=auth.uid()::text and exists(select 1 from public.book_owners where owner_id=auth.uid()));
