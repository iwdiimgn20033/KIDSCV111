-- حسابات الطلاب باسم مستخدم وكلمة مرور، بدون الحاجة لأي إعداد في صفحة Authentication.
-- انسخي هذا الملف كاملاً في SQL Editor واضغطي Run مرة واحدة.

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.kid_accounts (
  username text primary key,
  pass_hash text not null,
  created_at timestamptz not null default now()
);
create table if not exists public.kid_sessions (
  token uuid primary key default gen_random_uuid(),
  username text not null references public.kid_accounts(username) on delete cascade,
  created_at timestamptz not null default now()
);
create table if not exists public.kid_cvs (
  id uuid primary key default gen_random_uuid(),
  username text not null references public.kid_accounts(username) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists kid_cvs_user_idx on public.kid_cvs(username);
create table if not exists public.kid_login_fails (
  username text primary key,
  fails int not null default 0,
  locked_until timestamptz
);

-- لا أحد يقرأ الجداول مباشرة؛ كل شيء يمر عبر الدوال بالأسفل
alter table public.kid_accounts enable row level security;
alter table public.kid_sessions enable row level security;
alter table public.kid_cvs enable row level security;
alter table public.kid_login_fails enable row level security;
revoke all on public.kid_accounts, public.kid_sessions, public.kid_cvs, public.kid_login_fails from anon, authenticated;

create or replace function public.kid_user(p_token uuid) returns text
language plpgsql security definer set search_path = public, extensions as $$
declare u text;
begin
  select username into u from kid_sessions where token = p_token;
  if u is null then raise exception 'BAD_SESSION'; end if;
  return u;
end $$;

create or replace function public.kid_register(p_user text, p_pass text) returns uuid
language plpgsql security definer set search_path = public, extensions as $$
declare t uuid; u text := lower(trim(p_user));
begin
  if u !~ '^[a-z0-9._-]{3,30}$' then raise exception 'BAD_USERNAME'; end if;
  if length(coalesce(p_pass, '')) < 4 then raise exception 'SHORT_PASSWORD'; end if;
  if exists (select 1 from kid_accounts where username = u) then raise exception 'USERNAME_TAKEN'; end if;
  insert into kid_accounts(username, pass_hash) values (u, crypt(p_pass, gen_salt('bf')));
  insert into kid_sessions(username) values (u) returning token into t;
  return t;
end $$;

create or replace function public.kid_login(p_user text, p_pass text) returns uuid
language plpgsql security definer set search_path = public, extensions as $$
declare t uuid; h text; u text := lower(trim(p_user)); f kid_login_fails%rowtype;
begin
  select * into f from kid_login_fails where username = u;
  if f.locked_until is not null and f.locked_until > now() then raise exception 'LOCKED'; end if;
  select pass_hash into h from kid_accounts where username = u;
  if h is null or crypt(coalesce(p_pass, ''), h) <> h then
    if h is not null then
      insert into kid_login_fails(username, fails) values (u, 1)
      on conflict (username) do update set
        fails = case when kid_login_fails.fails + 1 >= 10 then 0 else kid_login_fails.fails + 1 end,
        locked_until = case when kid_login_fails.fails + 1 >= 10 then now() + interval '10 minutes' else kid_login_fails.locked_until end;
    end if;
    return null; -- اسم المستخدم أو كلمة المرور غير صحيحة
  end if;
  delete from kid_login_fails where username = u;
  insert into kid_sessions(username) values (u) returning token into t;
  return t;
end $$;

create or replace function public.kid_logout(p_token uuid) returns void
language sql security definer set search_path = public, extensions as $$
  delete from kid_sessions where token = p_token;
$$;

create or replace function public.kid_list(p_token uuid) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare u text := kid_user(p_token);
begin
  return coalesce((select jsonb_agg(jsonb_build_object('id', id, 'data', data, 'created_at', created_at) order by created_at)
                   from kid_cvs where username = u), '[]'::jsonb);
end $$;

create or replace function public.kid_new(p_token uuid, p_data jsonb) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare u text := kid_user(p_token); r kid_cvs%rowtype;
begin
  if (select count(*) from kid_cvs where username = u) >= 20 then raise exception 'TOO_MANY'; end if;
  insert into kid_cvs(username, data) values (u, coalesce(p_data, '{}'::jsonb)) returning * into r;
  return jsonb_build_object('id', r.id, 'data', r.data, 'created_at', r.created_at);
end $$;

create or replace function public.kid_save(p_token uuid, p_id uuid, p_data jsonb) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare u text := kid_user(p_token);
begin
  update kid_cvs set data = coalesce(p_data, '{}'::jsonb), updated_at = now() where id = p_id and username = u;
end $$;

create or replace function public.kid_delete(p_token uuid, p_id uuid) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare u text := kid_user(p_token);
begin
  delete from kid_cvs where id = p_id and username = u;
end $$;


-- دخول بخطوة واحدة: إذا كان الاسم جديداً يُنشأ الحساب، وإلا يُتحقق من الرمز
create or replace function public.kid_enter(p_user text, p_pass text) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare u text := lower(trim(p_user)); t uuid;
begin
  if u !~ '^[a-z0-9._-]{3,30}$' then raise exception 'BAD_USERNAME'; end if;
  if length(coalesce(p_pass, '')) < 4 then raise exception 'SHORT_PASSWORD'; end if;
  if not exists (select 1 from kid_accounts where username = u) then
    t := kid_register(u, p_pass);
    return jsonb_build_object('token', t, 'created', true);
  end if;
  t := kid_login(u, p_pass);
  if t is null then return null; end if;
  return jsonb_build_object('token', t, 'created', false);
end $$;

revoke all on function public.kid_user(uuid) from public, anon, authenticated;
grant execute on function public.kid_enter(text, text), public.kid_register(text, text), public.kid_login(text, text), public.kid_logout(uuid),
  public.kid_list(uuid), public.kid_new(uuid, jsonb), public.kid_save(uuid, uuid, jsonb), public.kid_delete(uuid, uuid)
  to anon, authenticated;
