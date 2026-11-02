# A Festa dos Meus 50 — site + painel, publicado sozinho no GitHub

```
index.html     Site, painel (#admin), fontes e dados — tudo num ficheiro
musica/        As 5 faixas do gira-discos (só tocam quando o convidado carrega)
LEIA-ME.md     Este guia
```

- **Convidados:** `https://O-TEU-UTILIZADOR.github.io/festa50/`
- **Painel:** o mesmo endereço com `#admin` no fim. Pede a password.

A configuração abaixo faz-se **uma vez** (cerca de 10 minutos). A partir daí, quem gere o painel só edita: cada alteração vai sozinha para o GitHub e fica no ar em 1–2 minutos. Ninguém precisa de carregar ficheiros.

---

## Configuração (uma vez, por quem perceber um pouco de GitHub)

### 1. Criar o repositório
1. Entra em <https://github.com> (cria conta, se não tiveres).
2. Cria um repositório novo: **New repository**, com o nome `festa50` e visibilidade **Public**. O GitHub Pages grátis exige que seja público.
3. Escolhe **Add file → Upload files** e arrasta o `index.html` e a pasta `musica` inteira. Carrega em **Commit changes**.

### 2. Ligar o GitHub Pages
No repositório, vai a **Settings → Pages → Build and deployment**. Escolhe **Source: Deploy from a branch** e **Branch: `main` / (root)**, e carrega em **Save**.
Passado um ou dois minutos, o site fica em `https://O-TEU-UTILIZADOR.github.io/festa50/`.

### 3. Criar o token (a "chave" que deixa o painel publicar)
1. Abre <https://github.com/settings/personal-access-tokens/new> (o tipo *Fine-grained token*).
2. Preenche assim:
   - **Token name:** `Festa 50 — painel`
   - **Expiration:** *Custom*, por exemplo 31/01/2027 (depois da festa).
   - **Repository access:** *Only select repositories* → `festa50`
   - **Permissions → Repository permissions:**
     - **Contents:** *Read and write*
     - **Pages:** *Read-only* — opcional; serve para o painel dizer "No ar ✓".
3. Carrega em **Generate token** e copia o token (começa por `github_pat_`).

### 4. Ligar o painel ao GitHub
1. Abre `https://O-TEU-UTILIZADOR.github.io/festa50/#admin` e entra com a password.
2. Vai a **Definições → Publicação automática no GitHub** e preenche:
   - **Utilizador:** o teu utilizador do GitHub
   - **Repositório:** `festa50`
   - **Token:** cola o token
3. Carrega em **Testar ligação**. Deve aparecer "Ligação OK". Depois carrega em **Guardar ligação**.
   O painel faz logo a primeira publicação. O token fica guardado **dentro do HTML, cifrado com a password**, por isso funciona em qualquer computador ou telemóvel onde se abra o painel.

### 5. Trocar a password
Em **Definições → Mudar a password**, escolhe uma **frase longa**, com 12 caracteres ou mais. Isto importa: o ficheiro é público, e a password protege a localização, as pistas por publicar e o token do GitHub.

### 6. Entregar a quem vai gerir
Passa-lhe só duas coisas: o link `…/festa50/#admin` e a password.

---

## No dia a dia (para quem gere o painel)
1. Abre o link do painel e escreve a password.
2. Muda o que precisares: pistas, textos, horários, localização.
3. Pronto. A barra preta em baixo mostra o estado: *"A publicar…"*, depois *"Publicado às 17:30"*, depois *"No ar ✓"*.
   - Os convidados que já tinham o site aberto podem ter de o recarregar.
   - O GitHub pode guardar a versão antiga em cache até ~10 minutos.

Se preferires rever antes de pôr no ar, em **Definições** desliga *"Publicar automaticamente"*. A partir daí publicas com o botão **Publicar agora**.

**Dois aparelhos ao mesmo tempo:** se alguém publicar noutro computador, o painel avisa em vez de apagar o trabalho dessa pessoa. Fecha e volta a abrir o painel, que carrega a versão mais recente.

---

## O gira-discos
- Tocar no disco toca a primeira faixa (ou pausa). Tocar numa faixa toca essa.
- No fim de cada faixa, passa à seguinte.
- Aparece um mini-leitor no topo para pausar em qualquer parte do site.
- **Nada toca sozinho:** o som só começa quando o convidado carrega.
- Títulos e notas editam-se em **Conteúdo → Banda sonora**. Para trocar uma música, carrega o `.mp3` para a pasta `musica/` do repositório e muda o campo *Ficheiro de áudio*.

## O que é público e o que é segredo
| Dentro do `index.html` | Quem lê |
|---|---|
| Textos, data, pistas publicadas, localização revelada | Toda a gente |
| Pistas em rascunho, localização escondida, registo de alterações, **token do GitHub** | Só com a password (cifra AES-256-GCM) |
| Pistas e revelação **agendadas** | Escondidas, mas não cifradas. Aparecem à hora marcada, segundo o relógio de cada telemóvel. Um curioso técnico conseguiria lê-las antes. Para segredo total: deixa em rascunho e publica à hora. |

- **Confirmações e sugestões:** vão por WhatsApp.
- **Password perdida:** não há recuperação. Guarda a *cópia (JSON)* em **Definições**, num sítio privado.
- **O token:** expira na data que escolheste. Se o apagares no GitHub, o painel volta a publicar por download.
