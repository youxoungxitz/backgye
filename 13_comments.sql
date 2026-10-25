-- 백계성: 계단참 게시판 댓글 + 답글
-- SQL Editor → New query에 붙여 넣고 Run. 여러 번 실행해도 괜찮다. 지우는 것은 없다.
-- 12_board.sql을 먼저 실행해 둔 상태여야 한다.
create table if not exists public.tip_comments (
  id bigint generated always as identity primary key,
  post_id bigint not null references public.tip_posts(id) on delete cascade,
  parent_id bigint references public.tip_comments(id) on delete cascade,
  author uuid not null references public.characters(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 300),
  deleted boolean not null default false,
  created_at timestamptz not null default now(),
  edited_at timestamptz
);
create index if not exists tip_comments_post on public.tip_comments (post_id, created_at);
alter table public.tip_comments enable row level security;

-- 답글의 부모는 같은 글의 '댓글'이어야 한다 (답글의 답글은 같은 댓글 밑에 붙는다)
create or replace function public.tip_parent_ok(p_parent bigint, p_post bigint)
returns boolean language sql stable security definer set search_path = public as $$
  select p_parent is null or exists (
    select 1 from public.tip_comments c where c.id = p_parent and c.post_id = p_post and c.parent_id is null)
$$;

drop policy if exists tipc_read on public.tip_comments;
create policy tipc_read on public.tip_comments for select to authenticated using (true);
drop policy if exists tipc_insert on public.tip_comments;
create policy tipc_insert on public.tip_comments for insert to authenticated
  with check (public.owns(author) and deleted = false and public.tip_parent_ok(parent_id, post_id));
drop policy if exists tipc_update on public.tip_comments;
create policy tipc_update on public.tip_comments for update to authenticated
  using (public.owns(author) or public.is_admin()) with check (public.owns(author) or public.is_admin());
drop policy if exists tipc_delete on public.tip_comments;
create policy tipc_delete on public.tip_comments for delete to authenticated using (public.owns(author) or public.is_admin());
-- 고칠 수 있는 칸은 글·지움 표시·고친 시각뿐 (글쓴이나 붙은 글은 못 바꾼다)
revoke update on public.tip_comments from authenticated;
grant update (body, deleted, edited_at) on public.tip_comments to authenticated;
