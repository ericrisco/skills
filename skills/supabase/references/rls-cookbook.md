# RLS cookbook

Concrete Row Level Security patterns. Every policy assumes RLS is enabled on the table
(`alter table X enable row level security;`) and is scoped `to authenticated` unless a public-read case
explicitly needs `anon`. Always pair owner/tenant predicates with an index on the filtered column.

## Owner-only (per-user rows)

```sql
alter table documents enable row level security;

create policy "owner full access" on documents
  for all to authenticated
  using ( user_id = (select auth.uid()) )
  with check ( user_id = (select auth.uid()) );

create index on documents (user_id);
```

`using` gates which rows are *visible* (select/update/delete); `with check` gates what *new/updated*
rows are allowed (insert/update). Set both or an update can move a row out of your reach.

## Multi-tenant (team_id via membership table)

Don't inline a correlated subquery against the membership table in every policy — it re-runs per row.
Use a `security definer` helper that runs once and is safe to index against.

```sql
create table memberships (
  user_id uuid not null references auth.users (id),
  team_id uuid not null references teams (id),
  primary key (user_id, team_id)
);

-- security definer: runs with the function owner's rights, bypassing RLS on memberships,
-- so the helper itself doesn't recurse. Lock down its search_path.
create or replace function is_team_member(target_team uuid)
returns boolean
language sql
security definer
set search_path = ''
stable
as $$
  select exists (
    select 1 from public.memberships m
    where m.team_id = target_team
      and m.user_id = (select auth.uid())
  );
$$;

create policy "team members read" on projects
  for select to authenticated
  using ( is_team_member(team_id) );

create index on projects (team_id);
create index on memberships (user_id, team_id);
```

## Public-read, private-write

```sql
-- anyone (even anon) may read published rows
create policy "public reads published" on posts
  for select to anon, authenticated
  using ( status = 'published' );

-- only the author may write
create policy "author writes" on posts
  for all to authenticated
  using ( author_id = (select auth.uid()) )
  with check ( author_id = (select auth.uid()) );
```

## Storage object policies

`storage.objects` is a normal table; policy it the same way. Convention: prefix paths with the owner id
so the policy can parse it.

```sql
create policy "users manage own avatar folder" on storage.objects
  for all to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
```

## Realtime private channel (realtime.messages)

Private Broadcast/Presence channels are authorized by RLS on `realtime.messages`. The channel name is
available as `realtime.topic()`.

```sql
create policy "members read room broadcasts" on realtime.messages
  for select to authenticated
  using ( is_team_member( (realtime.topic())::uuid ) );

create policy "members write room broadcasts" on realtime.messages
  for insert to authenticated
  with check ( is_team_member( (realtime.topic())::uuid ) );
```

## Testing a policy locally

Simulate an authenticated request inside `psql` / a migration test by switching role and faking the JWT
claims that `auth.uid()` reads.

```sql
begin;
  set local role authenticated;
  set local request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000001"}';

  -- auth.uid() now returns that sub; run the query you expect a user to make
  select * from documents;        -- should return only that user's rows
rollback;
```

Reset with `reset role;`. Run the same query as `anon` to confirm it returns nothing where it should.
