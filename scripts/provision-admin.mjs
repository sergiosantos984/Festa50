// Cria (ou promove) a conta de administrador — corre no TEU computador, nunca no browser.
//
// Requer Node 18+. Sem dependências.
// As credenciais vêm de variáveis de ambiente — não ficam escritas em ficheiro nenhum:
//
//   export SUPABASE_URL="https://xxxx.supabase.co"
//   read -s SUPABASE_SECRET_KEY        # chave secreta / service_role (Project Settings → API Keys)
//   export SUPABASE_SECRET_KEY
//   export ADMIN_EMAIL="o-teu-email@exemplo.pt"
//   read -s ADMIN_INITIAL_PASSWORD     # a password inicial (escrita às escuras)
//   export ADMIN_INITIAL_PASSWORD
//   node scripts/provision-admin.mjs
//
// Depois, fecha o terminal (as variáveis desaparecem) e muda a password no painel.

const url = (process.env.SUPABASE_URL || "").replace(/\/$/, "");
const key = process.env.SUPABASE_SECRET_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || "";
const email = (process.env.ADMIN_EMAIL || "").trim().toLowerCase();
const password = process.env.ADMIN_INITIAL_PASSWORD || "";

function fail(msg) { console.error("✗ " + msg); process.exit(1); }
if (!/^https:\/\/[a-z0-9-]+\.supabase\.co$/i.test(url) && !/^https?:\/\//.test(url)) fail("SUPABASE_URL em falta ou inválido.");
if (!key) fail("SUPABASE_SECRET_KEY em falta.");
if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) fail("ADMIN_EMAIL em falta ou inválido.");
if (password.length < 10) fail("ADMIN_INITIAL_PASSWORD tem de ter pelo menos 10 caracteres.");

const headers = { apikey: key, "Content-Type": "application/json" };
if (key.startsWith("eyJ")) headers.Authorization = "Bearer " + key; // chave antiga (JWT); as novas sb_secret_ só precisam de apikey

async function call(path, opts = {}) {
  const r = await fetch(url + path, { ...opts, headers: { ...headers, ...(opts.headers || {}) } });
  const text = await r.text();
  let body; try { body = text ? JSON.parse(text) : null; } catch { body = text; }
  return { ok: r.ok, status: r.status, body };
}

async function findUser() {
  for (let page = 1; page <= 20; page++) {
    const r = await call(`/auth/v1/admin/users?page=${page}&per_page=200`);
    if (!r.ok) fail("Não consegui listar utilizadores: " + JSON.stringify(r.body));
    const users = r.body.users || [];
    const u = users.find((x) => (x.email || "").toLowerCase() === email);
    if (u) return u;
    if (users.length < 200) return null;
  }
  return null;
}

let user = await findUser();
if (user) {
  console.log("• A conta já existe — não mudo a password. Vou só garantir que é administradora.");
} else {
  const r = await call("/auth/v1/admin/users", { method: "POST", body: JSON.stringify({ email, password, email_confirm: true }) });
  if (!r.ok) fail("Não consegui criar a conta: " + JSON.stringify(r.body));
  user = r.body.user || r.body;
  console.log("✓ Conta criada e confirmada: " + email);
}

const a = await call("/rest/v1/admins?on_conflict=user_id", {
  method: "POST", headers: { Prefer: "resolution=ignore-duplicates,return=minimal" }, body: JSON.stringify({ user_id: user.id })
});
if (!a.ok) fail("A conta existe mas não consegui dar-lhe permissões de admin: " + JSON.stringify(a.body) + "\nCorreste o supabase/migrations/001_schema.sql?");
console.log("✓ " + email + " é administrador(a). Entra em /admin.");
