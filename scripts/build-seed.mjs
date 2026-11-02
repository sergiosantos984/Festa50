// Gera supabase/seed.sql a partir de shared/defaults.js (fonte única do texto inicial).
// Uso: node scripts/build-seed.mjs
import { createRequire } from "node:module";
import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const D = require(join(here, "..", "shared", "defaults.js"));

const lit = (v) => "'" + String(v).replace(/'/g, "''") + "'";
const json = (o) => lit(JSON.stringify(o)) + "::jsonb";

// Pistas de exemplo: ficam em RASCUNHO (invisíveis para os convidados).
// São só ponto de partida — nenhuma descreve o local verdadeiro.
const clues = [
  ["Exemplo · cidade", "Pista n.º 1 — A cidade", "Uma pequena ajuda para os mais curiosos.",
   "Não precisas de sair de Lisboa para perceber que isto vai dar que falar.", "envelope"],
  ["Exemplo · ambiente", "Pista n.º 2 — O ambiente", "Para quem já está a escolher a roupa.",
   "Há sítios onde se vai para jantar. E há sítios de onde ninguém quer sair. Prepara-te para o segundo tipo.", "postal"],
  ["Exemplo · cenário", "Pista n.º 3 — O cenário", "Leva os óculos de sol. Ou não.",
   "Se a vista for boa, a conversa melhor ainda e o vinho estiver à altura, estamos no caminho certo.", "polaroid"],
  ["Exemplo · transporte", "Pista n.º 4 — Como lá chegar", "Spoiler: não é de submarino.",
   "Dá para chegar de carro, de táxi ou de boleia de um amigo responsável. Esta última é a que recomendo.", "bilhete"],
  ["Exemplo · fósforos", "Pista n.º 5 — A última antes do mapa", "A pista mais curta de todas.",
   "Quando esta caixa de fósforos abrir de vez, já não precisas de pistas. Precisas de chegar a horas.", "fosforos"]
];

const sql = `-- Gerado por scripts/build-seed.mjs a partir de shared/defaults.js — não editar à mão.
-- Corre DEPOIS de migrations/001_schema.sql. Não apaga nada que já exista.

insert into public.site_documents (key, draft, published, published_at)
values ('event',   ${json(D.event)},   ${json(D.event)},   now()),
       ('content', ${json(D.content)}, ${json(D.content)}, now())
on conflict (key) do nothing;

-- Localização: escondida, com a data do convite (16 de novembro) apenas como referência.
update public.location_reveal
   set venue_name = 'Local a revelar', venue_address = 'Lisboa', maps_url = '',
       reveal_message = 'Agora já sabes. Agora já não há desculpas.'
 where id = 1 and status = 'hidden' and maps_url = '';

insert into public.clues (internal_name, title, teaser, content, style, sort_order, status)
select v.* , 'draft' from (values
${clues.map((c, i) => `  (${lit(c[0])}, ${lit(c[1])}, ${lit(c[2])}, ${lit(c[3])}, ${lit(c[4])}, ${i + 1})`).join(",\n")}
) as v(internal_name, title, teaser, content, style, sort_order)
where not exists (select 1 from public.clues);
`;

writeFileSync(join(here, "..", "supabase", "seed.sql"), sql);
console.log("supabase/seed.sql gerado.");
