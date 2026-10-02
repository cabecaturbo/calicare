-- Phase 5.4: a daily count of meal-idea requests per account, for the rate
-- limit in the meal-ideas Edge Function. Only counts.
create table public.meal_ideas_usage (
    user_id uuid not null references auth.users (id) on delete cascade,
    day date not null,
    count integer not null default 0,
    primary key (user_id, day)
);
alter table public.meal_ideas_usage enable row level security;
revoke all on public.meal_ideas_usage from anon, authenticated;

create function public.note_meal_ideas_use() returns integer
language plpgsql security definer set search_path = public as $$
declare
    total integer;
begin
    if auth.uid() is null then
        raise exception 'Sign in first.' using errcode = '42501';
    end if;
    insert into public.meal_ideas_usage (user_id, day, count) values (auth.uid(), current_date, 1)
    on conflict (user_id, day) do update set count = public.meal_ideas_usage.count + 1
    returning count into total;
    return total;
end;
$$;
revoke all on function public.note_meal_ideas_use() from public, anon;
grant execute on function public.note_meal_ideas_use() to authenticated;
