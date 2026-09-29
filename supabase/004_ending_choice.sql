-- Run after 002 and 003. No reader receives deletion rights on database tables.
create table if not exists public.ending_choices (
 id bigint generated always as identity primary key,
 book_id text not null references public.book_owners(book_id) on delete cascade,
 choice text not null check(choice in ('keep','delete')),
 created_at timestamptz not null default now()
);
alter table public.ending_choices enable row level security;
revoke all on public.ending_choices from anon,authenticated;
grant select,delete on public.ending_choices to authenticated;
drop policy if exists "author manages ending choices" on public.ending_choices;
create policy "author manages ending choices" on public.ending_choices to authenticated
using(exists(select 1 from public.book_owners o where o.book_id=ending_choices.book_id and o.owner_id=auth.uid()));
create or replace function public.record_book_choice(p_book_id text,p_choice text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if p_choice is null or p_choice not in ('keep','delete') then raise exception 'Invalid choice'; end if;
 if not exists(select 1 from public.publications where book_id=p_book_id) then raise exception 'Книга ещё не опубликована'; end if;
 -- Deduplicate repeated identical submissions in a short interval.
 perform 1 from public.book_owners where book_id=p_book_id for update;
 if exists(select 1 from public.ending_choices where book_id=p_book_id and choice=p_choice and created_at>now()-interval '1 minute') then return; end if;
 insert into public.ending_choices(book_id,choice) values(p_book_id,p_choice);
end $$;
revoke all on function public.record_book_choice(text,text) from public;
grant execute on function public.record_book_choice(text,text) to anon,authenticated;
