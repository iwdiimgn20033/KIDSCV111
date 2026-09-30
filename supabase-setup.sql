-- جدول سِيَر الطلاب: كل ولي أمر (رقم هاتف) يرى سِيَر أبنائه فقط
create table if not exists public.student_cvs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists student_cvs_user_idx on public.student_cvs(user_id);

alter table public.student_cvs enable row level security;

drop policy if exists "read own cvs" on public.student_cvs;
drop policy if exists "insert own cvs" on public.student_cvs;
drop policy if exists "update own cvs" on public.student_cvs;
drop policy if exists "delete own cvs" on public.student_cvs;

create policy "read own cvs"   on public.student_cvs for select to authenticated using (auth.uid() = user_id);
create policy "insert own cvs" on public.student_cvs for insert to authenticated with check (auth.uid() = user_id);
create policy "update own cvs" on public.student_cvs for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "delete own cvs" on public.student_cvs for delete to authenticated using (auth.uid() = user_id);
