/*
 * A FESTA DOS MEUS 50 — conteúdo por omissão
 * ------------------------------------------------------------------
 * Fonte única do texto inicial do site. É usado:
 *   1. Para gerar o seed da base de dados (scripts/build-seed.mjs);
 *   2. Como texto de recurso no site público, se a base de dados
 *      estiver em baixo ou ainda não estiver configurada.
 *
 * Depois de a base de dados estar ligada, o texto que conta é o que
 * editas no /admin. Este ficheiro NÃO contém pistas nem a localização:
 * tudo o que está aqui é público por definição.
 */
(function (root) {
  var FESTA_DEFAULTS = {
    event: {
      title: "A festa dos meus 50",
      headline: "50 ANOS.",
      subtitle: "Finalmente!",
      intro_message: "Há coisas que chegam cedo, outras a tempo, e esta... chegou finalmente.",
      final_message: "E ainda há tanto para viver.",
      description: "Boa comida. Bons vinhos. Grandes conversas. Velhos amigos. Novas histórias. O essencial!",
      date: "2026-11-21",
      start_time: "14:30",
      end_date: "2026-11-22",
      end_time: "03:00",
      timezone: "Europe/Lisbon",
      city: "Lisboa",
      capacity: 50,
      capacity_description: "As 50 pessoas mais marcantes da minha vida.",
      capacity_message: "Não há segunda edição garantida.",
      whatsapp_number: "351936266342",
      rsvp_message: "Olá! Confirmo a minha presença na festa dos teus 50 anos, no dia {data}. Conta comigo!",
      suggestion_message: "Olá! Para a festa dos teus 50, acho que não pode mesmo faltar: {nome}.",
      rsvp_deadline_text: "",
      suggestions_mode: "backend"
    },

    content: {
      sections: { signpost: true, checklist: true, music: true, suggest: true, rules: true },

      intro: {
        loading: "Carregamento de grandes decisões...",
        line2: "50 anos. Já não era sem tempo.",
        button: "ENTRAR NA HISTÓRIA",
        skip: "Saltar intro"
      },

      hero: {
        kicker: "Save the date",
        tagline: "Menos pressa. Mais vida.",
        side_note: "As boas histórias não têm prazo.",
        sun_note: "O sol também se põe. Nós é que não.",
        conto: "Conto contigo.",
        concept: "50 anos. Mil histórias. E ainda agora começámos.",
        tap_note: "Confirmado: meio século.",
        egg_five: "Já percebeste a idade. Não é preciso confirmar cinco vezes.",
        scroll_hint: "Desliza para entrar"
      },

      signpost: {
        kicker: "De onde vêm os 50",
        title: "Cada placa, um capítulo.",
        subtitle: "E em cada capítulo, gente que não podia faltar.",
        items: ["Família", "Calçada", "Salesianos", "Faculdade", "Campos de Férias", "Alfeite",
                "Andebol", "SPC", "Bailes da Vida", "Escuteiros", "Prazeres", "Carvalhais"],
        tap_note: "Capítulo guardado em boa memória."
      },

      checklist: {
        kicker: "A vida é curta. A lista é restrita.",
        title: "Profissional de nada.",
        subtitle: "Especialista em aproveitar a vida.",
        items: [
          { label: "Relaxar", note: "Treino diário. Resultados visíveis." },
          { label: "Aproveitar a vida", note: "Objetivo anual largamente ultrapassado." },
          { label: "Boa comida", note: "Critério rigoroso. Segunda dose sempre aceite." },
          { label: "Boa companhia", note: "Aqui não se fazem concessões." },
          { label: "Rir muito", note: "Competência adquirida ao longo de vários anos de formação prática." },
          { label: "Repetir tudo amanhã, se possível", note: "Sujeito à disponibilidade do fígado." }
        ],
        essentials: "Boa comida. Bons vinhos. Grandes conversas. Velhos amigos. Novas histórias. O essencial!"
      },

      music: {
        kicker: "Lado A",
        title: "A banda sonora destes 50 anos",
        intro: "Há discos que se ouvem. E há discos que nos ouvem a nós.",
        artist: "Jorge Palma",
        tap_hint: "Toca no disco",
        silent_note: "Este gira-discos não toca som — de propósito. A música fica por tua conta.",
        songs: [
          { title: "Bairro do Amor", note: "Há músicas que envelhecem. Outras ficam connosco." },
          { title: "Deixa-me Rir", note: "Aos 50, rir deixou de ser hábito. Passou a ser método." },
          { title: "Frágil", note: "Frágil, só o copo. O resto aguenta-se bem." },
          { title: "Encosta-te a Mim", note: "Há amigos que servem de encosto há mais de trinta anos." },
          { title: "A Gente Vai Continuar", note: "Ainda agora começámos." }
        ],
        record_notes: [
          "Lado B: as histórias que não se contam ao jantar.",
          "Riscado? Não. Vivido.",
          "Este disco já deu mais voltas do que eu na Rotunda do Marquês.",
          "Continua a girar. Como nós."
        ]
      },

      invite: {
        kicker: "O convite oficial",
        title: "Fica a saber o essencial.",
        statement: "As 50 pessoas mais marcantes da minha vida.",
        date_note: "Sábado. Sem despertador.",
        time_note: "Doze horas e meia de festa. Convém treinar.",
        location_note: "Toca para ir às pistas.",
        group_note: "Depois de confirmares, entras no grupo da festa — e lá vês quem está convocado.",
        calendar_button: "ADICIONAR AO CALENDÁRIO",
        lisboa: "Lisboa, sempre boa ideia."
      },

      mystery: {
        kicker: "O mistério",
        title: "MAS AFINAL, ONDE É QUE ISTO VAI SER?",
        subtitle: "Calma. Até aos 50 cheguei. Não esperes que agora revele tudo à primeira.",
        comeback: "Novas pistas aparecem quando o aniversariante achar que já mereces saber mais. Volta cá de vez em quando.",
        empty: "Ainda não há pistas. O suspense também faz parte da festa.",
        locked_label: "Esta pista ainda está a ganhar coragem.",
        random_button: "Pedir uma pista ao acaso",
        shake_enable: "Ativar o modo abanar",
        shake_messages: [
          "Calma, Colombo. Ainda não chegaste lá.",
          "Abanar o telemóvel não acelera o calendário.",
          "O GPS do aniversariante está em modo avião."
        ],
        location_locked: "Curiosidade é uma qualidade. Mas ainda não é desta."
      },

      reveal: {
        kicker: "Finalmente (outra vez)!",
        title: "É aqui.",
        maps_button: "ABRIR LOCALIZAÇÃO NO GOOGLE MAPS",
        hidden_button: "LOCALIZAÇÃO A REVELAR",
        scheduled_text: "A revelação está marcada para {data}."
      },

      suggest: {
        title: "FALTA AQUI ALGUÉM?",
        subtitle: "Quem achas que não pode mesmo faltar?",
        note: "É uma sugestão, não um convite automático. A decisão final cabe ao aniversariante — e à lotação.",
        placeholder: "Nome da pessoa",
        button: "ENVIAR SUGESTÃO",
        whatsapp_button: "SUGERIR PELO WHATSAPP",
        responses: [
          "Sugestão recebida. O conselho de administração dos 50 irá analisar o processo.",
          "Fica registado. Agora deixa-me fingir que tenho a decisão tomada.",
          "Anotado no caderno. O caderno não esquece; o aniversariante, às vezes.",
          "Recebido. Vai a votos numa assembleia de um só membro."
        ]
      },

      rsvp: {
        kicker: "Agora é contigo",
        title: "CONFIRMAR PRESENÇA",
        cta: "SIM, CONTO ESTAR CONTIGO!",
        subtitle: "Uma resposta simples. Uma grande responsabilidade. Um excelente dia pela frente.",
        note: "O botão abre o WhatsApp com a mensagem pronta. A confirmação só fica feita quando a enviares.",
        after: "Abriu o WhatsApp? Falta só carregar em enviar."
      },

      rules: {
        title: "AS REGRAS DE OURO",
        items: [
          { title: "O convite é pessoal e intransmissível.", joke: "Não é um bilhete de avião. Não dá para passar ao primo." },
          { title: "A lista é limitada a 50 pessoas.", joke: "Fiz as contas: uma pessoa por ano. Não sobra nenhuma." },
          { title: "Não partilhes o convite com outras pessoas.", joke: "Um segredo partilhado é um convite a mais — e a sala não estica." },
          { title: "Se tiveres sugestões de convidados, fala diretamente com o aniversariante.", joke: "Ou usa a caixa de sugestões. Ele lê tudo. Demora, mas lê." },
          { title: "A localização será revelada quando chegar a altura.", joke: "A paciência é a única coisa que não precisas de levar para a festa." }
        ]
      },

      ending: {
        lines: ["50 anos.", "Boas pessoas. Grandes histórias."],
        last: "Conto contigo.",
        carnation: "25 de Abril... sempre.",
        hidden_note: "Se chegaste até aqui, mereces pelo menos um copo de água.",
        review_button: "REVER AS PISTAS",
        rsvp_button: "CONFIRMAR PRESENÇA"
      },

      countdown: {
        before: "Faltam",
        during: "A festa está a acontecer. Agora mesmo.",
        after: "Já foi. E foi daquelas que ficam."
      }
    }
  };

  if (typeof module !== "undefined" && module.exports) module.exports = FESTA_DEFAULTS;
  else root.FESTA_DEFAULTS = FESTA_DEFAULTS;
})(typeof window !== "undefined" ? window : this);
