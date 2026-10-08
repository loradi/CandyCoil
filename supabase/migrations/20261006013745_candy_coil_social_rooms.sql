create table public.game_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  handle text not null unique check (handle ~ '^[A-Za-z0-9_]{3,20}$'),
  friend_code text not null unique default upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
  created_at timestamptz not null default now()
);

create table public.game_rooms (
  id uuid primary key default gen_random_uuid(),
  invite_code text not null unique default upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
  host_id uuid not null references auth.users(id) on delete cascade,
  title text not null default 'Candy Coil Room' check (char_length(title) between 1 and 48),
  status text not null default 'waiting' check (status in ('waiting', 'running', 'closed')),
  max_players smallint not null default 8 check (max_players between 2 and 12),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '2 hours'
);

create index game_rooms_waiting_created_idx on public.game_rooms (created_at desc) where status = 'waiting';
create index game_rooms_host_idx on public.game_rooms (host_id);
create index game_rooms_expiry_idx on public.game_rooms (expires_at);

create table public.game_room_members (
  room_id uuid not null references public.game_rooms(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  handle text not null check (char_length(handle) between 3 and 20),
  seat smallint not null check (seat between 1 and 12),
  joined_at timestamptz not null default now(),
  primary key (room_id, user_id),
  unique (room_id, seat)
);

create index game_room_members_user_idx on public.game_room_members (user_id);

create table public.game_friend_requests (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references auth.users(id) on delete cascade,
  recipient_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  check (sender_id <> recipient_id),
  unique (sender_id, recipient_id)
);

create index game_friend_requests_recipient_idx on public.game_friend_requests (recipient_id, status);
create index game_friend_requests_sender_idx on public.game_friend_requests (sender_id, status);

alter table public.game_profiles enable row level security;
alter table public.game_rooms enable row level security;
alter table public.game_room_members enable row level security;
alter table public.game_friend_requests enable row level security;

grant select, insert, update on public.game_profiles to authenticated;
grant select, insert, update, delete on public.game_rooms to authenticated;
grant select, insert, delete on public.game_room_members to authenticated;
grant select, insert, update on public.game_friend_requests to authenticated;

create policy "Game handles are discoverable"
  on public.game_profiles for select to authenticated using (true);
create policy "Players create their own game profile"
  on public.game_profiles for insert to authenticated with check (user_id = (select auth.uid()));
create policy "Players update their own game profile"
  on public.game_profiles for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "Waiting game rooms are joinable by invite or matchmaking"
  on public.game_rooms for select to authenticated
  using (status = 'waiting' or host_id = (select auth.uid()));
create policy "Players create rooms as their own host"
  on public.game_rooms for insert to authenticated
  with check (host_id = (select auth.uid()));
create policy "Hosts control their rooms"
  on public.game_rooms for update to authenticated
  using (host_id = (select auth.uid()))
  with check (host_id = (select auth.uid()));
create policy "Hosts delete their rooms"
  on public.game_rooms for delete to authenticated
  using (host_id = (select auth.uid()));

create policy "Lobby roster is public player identity only"
  on public.game_room_members for select to authenticated using (true);
create policy "Players join as themselves"
  on public.game_room_members for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.game_rooms r where r.id = room_id and r.status = 'waiting')
  );
create policy "Players leave their own rooms"
  on public.game_room_members for delete to authenticated
  using (user_id = (select auth.uid()));

create policy "Players see only their own friend requests"
  on public.game_friend_requests for select to authenticated
  using (sender_id = (select auth.uid()) or recipient_id = (select auth.uid()));
create policy "Players send friend requests as themselves"
  on public.game_friend_requests for insert to authenticated
  with check (sender_id = (select auth.uid()) and recipient_id <> (select auth.uid()));
create policy "Recipients respond to their own requests"
  on public.game_friend_requests for update to authenticated
  using (recipient_id = (select auth.uid()) and status = 'pending')
  with check (recipient_id = (select auth.uid()) and status in ('accepted', 'declined'));

create function public.game_enforce_lobby_capacity()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  room_limit smallint;
  room_status text;
  member_count integer;
begin
  perform pg_advisory_xact_lock(hashtextextended(new.room_id::text, 0));

  select r.max_players, r.status
    into room_limit, room_status
    from public.game_rooms r
    where r.id = new.room_id;

  if not found or room_status <> 'waiting' then
    raise exception 'This room is no longer accepting players';
  end if;

  if new.seat > room_limit then
    raise exception 'This room has no more player seats';
  end if;

  select count(*) into member_count
    from public.game_room_members m
    where m.room_id = new.room_id;

  if member_count >= room_limit then
    raise exception 'This room is full';
  end if;

  return new;
end;
$$;

create trigger game_room_member_capacity
  before insert on public.game_room_members
  for each row execute function public.game_enforce_lobby_capacity();

revoke all on function public.game_enforce_lobby_capacity() from public, anon, authenticated;
