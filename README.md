# A Festa dos Meus 50 — Finalmente!

Site de convite (público, cinematográfico, pensado para telemóvel) + painel privado em `/admin` para gerires tudo sem tocar em código: detalhes do evento, textos, pistas, agendamentos e a revelação da localização.

---

## 1. O que está nesta pasta

```
index.html                  O site que os convidados abrem (HTML + CSS + JS num só ficheiro)
config.js                   Ligação ao Supabase (URL + chave pública). ÚNICO ficheiro a preencher.
og.jpg                      Imagem da pré-visualização no WhatsApp
fonts/                      Fontes alojadas no próprio site (sem Google Fonts)
shared/defaults.js          Texto inicial de todo o site (usado também como reserva se a base de dados falhar)
admin/index.html            O painel de controlo
admin/vendor/               Biblioteca oficial supabase-js 2.118.0 (incluída, sem CDN)
supabase/migrations/
  001_schema.sql            Tabelas, regras de segurança (RLS) e funções — obrigatório
  002_storage.sql           Imagens das pistas — opcional
supabase/seed.sql           Texto inicial + 5 pistas de exemplo EM RASCUNHO (ninguém as vê)
scripts/provision-admin.mjs Cria a conta de administrador a partir do teu computador (alternativa ao painel do Supabase)
scripts/build-seed.mjs      Regenera seed.sql a partir de shared/defaults.js
tests/security_test.sql     Testes de segurança da base de dados
```

## 2. Como funciona (em 30 segundos)

- O site é **estático** (pode estar em qualquer alojamento grátis). Ao abrir, pede ao Supabase uma única coisa: `get_public_site()`.
- Essa função, no servidor, devolve **só o que está publicado**. Pistas em rascunho, pistas agendadas antes da hora, a localização escondida, sugestões e notas **nunca saem da base de dados**. Não é CSS a esconder — os dados simplesmente não são enviados.
- O agendamento (pistas e localização) é decidido pelo **relógio do servidor**, em cada pedido. Não há temporizadores no telemóvel do convidado, nem tarefas agendadas que possam falhar: à hora marcada, o próximo convidado que abrir o site já vê.
- O painel `/admin` usa **Supabase Auth** (email + password). Cada operação é verificada no servidor (`is_admin()`), por isso esconder botões não é a segurança — a base de dados recusa sozinha quem não é administrador.
- Mudanças nos textos e detalhes do evento são **rascunho** até carregares em **Publicar**. Pistas e localização têm o seu próprio estado (rascunho / agendada / publicada / arquivada; escondida / agendada / revelada).
- **Confirmações de presença: por WhatsApp.** O botão abre uma conversa contigo com a mensagem pronta; só conta quando o convidado a envia. O site não regista nem conta confirmações e não finge que o faz.
- **Sugestões de convidados:** por omissão ficam guardadas no painel (privadas). Podes mudar para "por WhatsApp" ou desligar em *Detalhes do Evento*.

## 3. Pôr no ar — passo a passo (±20 minutos)

### 3.1 Criar o projeto Supabase
1. Vai a <https://supabase.com>, cria conta e um **New project** (região **EU — Frankfurt ou Paris**; o plano grátis chega).
2. Guarda a password da base de dados num sítio seguro (não é a do painel da festa).

### 3.2 Criar as tabelas
No Supabase → **SQL Editor** → *New query*, cola e corre, por esta ordem:
1. todo o conteúdo de `supabase/migrations/001_schema.sql`
2. todo o conteúdo de `supabase/seed.sql`
3. (opcional, para imagens nas pistas) `supabase/migrations/002_storage.sql`

### 3.3 Fechar o registo público
Supabase → **Authentication → Sign In / Providers** → desliga **"Allow new users to sign up"**.
(Mesmo que alguém conseguisse criar conta, não teria acesso: só quem está na tabela `admins` é administrador. Mas assim fica fechado à mesma.)

### 3.4 Criar a tua conta de administrador (com a password inicial)
A password **nunca** fica escrita em ficheiro nenhum do site. Escolhe **uma** das opções:

**Opção A — pelo painel do Supabase (mais simples)**
1. **Authentication → Users → Add user → Create new user**
2. Email: o teu email · Password: `AntonioTrinca50` · marca **Auto Confirm User** → *Create user*.
3. No **SQL Editor**, corre (com o teu email):
   ```sql
   insert into public.admins (user_id)
   select id from auth.users where email = 'o-teu-email@exemplo.pt'
   on conflict do nothing;
   ```

**Opção B — pelo terminal** (Node 18+), sem a password ficar no histórico:
```bash
export SUPABASE_URL="https://xxxx.supabase.co"
read -s SUPABASE_SECRET_KEY && export SUPABASE_SECRET_KEY     # Project Settings → API Keys → secret / service_role
export ADMIN_EMAIL="o-teu-email@exemplo.pt"
read -s ADMIN_INITIAL_PASSWORD && export ADMIN_INITIAL_PASSWORD
node scripts/provision-admin.mjs
```
A chave secreta só existe no teu terminal durante este comando. **Nunca** a coloques no `config.js` nem em nenhum ficheiro do site.

👉 Depois do primeiro login, muda a password em **Definições → Mudar a password**.

### 3.5 Ligar o site à base de dados
Abre `config.js` e preenche (Supabase → **Project Settings → API Keys / Data API**):
```js
window.FESTA_CONFIG = {
  supabaseUrl: "https://xxxx.supabase.co",
  supabaseAnonKey: "a chave anon / publishable"
};
```
A chave *anon/publishable* é pública por natureza — com ela só se consegue ler o que está publicado e enviar sugestões.

### 3.6 Endereço para recuperar a password
Supabase → **Authentication → URL Configuration**:
- **Site URL:** o endereço do teu site, ex.: `https://festa50.netlify.app`
- **Redirect URLs:** acrescenta `https://festa50.netlify.app/admin/`

### 3.7 Publicar o site
É uma pasta estática — qualquer destes serve:
- **Netlify Drop** (o mais rápido): <https://app.netlify.com/drop> → arrasta a pasta inteira. Podes mudar o nome do site para algo como `festa50-xxxx`.
- **Cloudflare Pages / Vercel**: novo projeto, "upload" da pasta, sem passo de build.
- **GitHub Pages**: põe a pasta num repositório e ativa Pages (o `/admin/` funciona tal e qual).

Depois de publicar:
- O site: `https://o-teu-endereco/`
- O painel: `https://o-teu-endereco/admin/`
- Para a pré-visualização bonita no WhatsApp, troca em `index.html` a linha `og:image` para o endereço completo: `content="https://o-teu-endereco/og.jpg"`.

> **Mudanças feitas no painel não precisam de nova publicação do site.** Só precisas de voltar a publicar a pasta se mudares ficheiros (por exemplo, o `config.js`).

## 4. Usar o painel

| Quero… | Onde |
|---|---|
| Ver o estado geral | **Visão Geral** |
| Mudar data, horas, lotação, WhatsApp, mensagens | **Detalhes do Evento** → *Guardar alterações* → barra preta → **Publicar** |
| Mudar qualquer texto do site, ligar/desligar secções | **Conteúdo do Website** → *Guardar* → **Publicar** |
| Ver como fica antes de publicar | **Pré-visualizar** (abre o site com os rascunhos, com uma faixa vermelha) |
| Criar uma pista | **Gestão de Pistas → + Nova Pista** (fica em rascunho) |
| Publicar já / agendar / tirar do ar | botões em cada pista: *Publicar*, *Agendar*, *Despublicar*, *Arquivar* |
| Mudar a ordem | setas ↑ ↓ (ou arrastar, no computador) |
| Preparar a localização | **Localização** → nome, morada, link do Google Maps → *Guardar* (continua escondida) |
| Revelar | **Revelar agora** (pede confirmação) ou **Agendar revelação** (ex.: 16 de novembro, 20h00) |
| Arrepender-me | **Esconder outra vez** / **Cancelar agendamento** |
| Gerir sugestões | **Sugestões de Convidados** (estado, nota privada, apagar, exportar CSV) |
| Mudar a password, cópia de segurança, registo de alterações | **Definições** |

**O link do Google Maps:** no Google Maps, abre o sítio → *Partilhar* → *Copiar link*. São aceites `google.com/maps`, `google.pt/maps`, `maps.google.com` e `maps.app.goo.gl`. O painel e a base de dados recusam qualquer outro endereço, e a revelação fica bloqueada enquanto não houver um link válido e o nome verdadeiro do local.

**Horas:** todas as datas do painel são **hora de Lisboa**, mesmo que estejas noutro fuso.

**Esqueci-me da password:** em `/admin`, escreve o email → *Esqueci-me da password* → segue o link que chega por email → escolhe a nova.

## 5. Segurança — o que é público e o que não é

| Público (qualquer pessoa com o link) | Privado (só o administrador) |
|---|---|
| Textos e detalhes **publicados** | Rascunhos de textos e detalhes |
| Pistas **publicadas** (ou agendadas, depois da hora) | Pistas em rascunho, arquivadas e agendadas antes da hora (só se sabe que "há uma pista a dia X") |
| Localização **depois** de revelada | Nome, morada e link antes da revelação |
| — | Sugestões de convidados e notas |
| — | Registo de alterações (inclui quem revelou o quê e quando) |

O que foi feito:
- Row Level Security em todas as tabelas; o papel público não tem acesso direto a nenhuma tabela.
- Todas as escritas passam por funções no servidor que validam os dados e confirmam `is_admin()`.
- O texto vindo da base de dados é sempre mostrado como texto (nunca HTML) — sem injeção de código.
- Links do mapa e das imagens validados no servidor e no browser; abrem com `rel="noopener noreferrer"`.
- Passwords geridas pelo Supabase Auth (guardadas com hash, nunca em texto); a password inicial não existe em nenhum ficheiro.
- Login: o Supabase limita tentativas no servidor; o painel acrescenta uma pausa crescente após 5 falhas.
- Registo de auditoria das ações importantes (sem passwords nem tokens).
- Sugestões: validação de tamanho e um travão anti-abuso (máx. 20 a cada 10 minutos e 500 no total).

Limites a ter em conta (honestamente):
- **Imagens das pistas**: ficam num "bucket" público com nome aleatório. Quem tiver o link exato vê a imagem, mesmo antes de a pista ser publicada. Não carregues fotos que revelem o local antes da hora.
- **"Pista revelada"** e **"já vi a intro"** são guardados no telemóvel do convidado (é só conforto, não segurança).
- **Abanar o telemóvel** depende do telemóvel: no iPhone pede autorização (com um toque) e há sempre o botão equivalente.
- Quem já viu a localização, sabe-a — *Esconder outra vez* só tira do site.

## 6. Cópias de segurança
- **Definições → Descarregar cópia (JSON)**: tudo (evento, textos, pistas, localização, sugestões, registo). Inclui a localização — guarda num sítio privado.
- **Sugestões → Exportar CSV**: abre no Excel/Numbers.
- O Supabase também faz cópias diárias da base de dados nos planos pagos.

## 7. Variáveis e segredos

| Nome | Onde vive | Público? |
|---|---|---|
| `supabaseUrl` | `config.js` | Sim |
| `supabaseAnonKey` (anon/publishable) | `config.js` | Sim — limitada por RLS e pelas funções |
| `SUPABASE_SECRET_KEY` (service_role/secret) | Só no teu terminal, se usares a opção B | **Não. Nunca no site.** |
| `ADMIN_EMAIL`, `ADMIN_INITIAL_PASSWORD` | Só no teu terminal (opção B) ou digitados no Supabase (opção A) | **Não** |

## 8. O que foi testado (e o que não)

**Testado de verdade:**
- `tests/security_test.sql` — corrido num Postgres 16 com a mesma emulação de papéis do Supabase (`anon`, `authenticated`, `auth.uid()` a partir do token). 28 verificações: convidados e utilizadores autenticados sem permissões não leem nem escrevem nada; funções internas fechadas; rascunhos e localização nunca saem; agendamentos respeitam o relógio do servidor; fuso de Lisboa (inverno e verão); fim do evento no dia seguinte; links não-Google e `javascript:` recusados; auditoria sem passwords.
- 67 verificações ponta-a-ponta no **Google Chrome real** (site + painel), contra essa base de dados local e um emulador local da API do Supabase (login por password + funções). Incluem: login certo/errado/sem permissões, mostrar password, rascunho invisível até publicar, persistência após recarregar, aviso ao sair sem guardar, criar/editar/publicar/agendar/reordenar/duplicar/arquivar/apagar pistas, estados bloqueada → disponível → revelada (e persistência), revelação com confirmação, botão do Maps ativo só com link válido, esconder e agendar outra vez, textos e secções publicados, sugestões (gravar, rever, CSV), mudar password, terminar sessão, ficheiro .ics (21/11 14h30 → 22/11 03h00, Europe/Lisbon), link do Google Calendar, link do WhatsApp codificado, e nenhum ficheiro do site com a password ou chave secreta.
- Larguras 320, 390, 412, 768 e 1440 px (site) e 390 px (painel): sem scroll horizontal, sem erros de JavaScript; também com "reduzir movimento" ligado.

**Não testado aqui (fazer no dia em que puseres no ar):**
- Um projeto Supabase real — sobretudo: Storage (imagens), o email de recuperação de password e o `scripts/provision-admin.mjs`.
- iPhone e Android reais (abertura do WhatsApp, modo abanar, tamanho com a barra do browser).

Checklist rápido depois de publicar: abrir o site no telemóvel → saltar intro → *Confirmar* abre o WhatsApp certo → entrar em `/admin` → criar e publicar uma pista de teste → vê-la no telemóvel → despublicar.

## 9. Testar no computador
```bash
cd festa50
python3 -m http.server 8080
# abre http://localhost:8080  (e http://localhost:8080/admin/)
```
Sem `config.js` preenchido, o site corre em modo estático (texto por omissão, localização escondida, sugestões por WhatsApp).

## 10. Notas
- O prazo de confirmação do convite original (1 de novembro) já passou, por isso o campo *Prazo de confirmação* está vazio — preenche-o em *Detalhes do Evento* se quiseres mostrar um novo.
- Jorge Palma aparece só como referência: nomes de canções e notas originais. Não há letras nem áudio. O gira-discos é silencioso de propósito (e diz isso).
- As placas dos capítulos (Família, Calçada, Salesianos, …) vêm do convite e são editáveis em *Conteúdo → Placas dos capítulos*.
- Dependências: supabase-js 2.118.0 (MIT, incluída) · fontes Bricolage Grotesque, Caveat, DM Sans (OFL) e Permanent Marker (Apache 2.0), incluídas em `fonts/`.
