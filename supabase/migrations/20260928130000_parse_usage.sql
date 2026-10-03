-- Phase 4.2: a daily count of care plan reads per account, for the rate
-- limit in the parse-care-plan Edge Function. Only counts: never the plan.
create table public.parse_usage (
    user_id uuid not null references auth.users (id) on delete cascade,
    day date not null,
    count integer not null default 0,
    primary key (user_id, day)
);
alter table public.parse_usage enable row level security;
revoke all on public.parse_usage from anon, authenticated;

-- Counts one use for the caller today and returns today's total.
create function public.note_parse_use() returns integer
language plpgsql security definer set search_path = public as $$
declare
    total integer;
begin
    if auth.uid() is null then
        raise exception 'Sign in first.' using errcode = '42501';
    end if;
    insert into public.parse_usage (user_id, day, count) values (auth.uid(), current_date, 1)
    on conflict (user_id, day) do update set count = public.parse_usage.count + 1
    returning count into total;
    return total;
end;
$$;
revoke all on function public.note_parse_use() from public, anon;
grant execute on function public.note_parse_use() to authenticated;
