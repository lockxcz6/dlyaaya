-- Run for an installation made from the previous archive. Also safe after schema.sql.
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

revoke all on function public.publish_book(text,integer,jsonb) from public,anon;
grant execute on function public.publish_book(text,integer,jsonb) to authenticated;
