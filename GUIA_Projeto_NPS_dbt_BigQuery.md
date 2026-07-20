# Projeto de Analytics Engineering — Pipeline de NPS (dbt + BigQuery)

**Contexto:** pesquisa de NPS de uma operadora de telecom do RN. Você vai pegar dados
brutos e sujos, carregar no BigQuery, limpar e modelar com dbt em camadas, testar,
documentar e visualizar. É o fluxo completo de um analytics engineer.

```
CSV bruto (sujo)  ──►  BigQuery (raw)  ──►  dbt staging (limpa)  ──►  dbt marts (modela)  ──►  testes + docs  ──►  dashboard
```

**Modelo alvo (star schema):**

```
                 dim_clientes
                      │
 dim_calendario ──┐   │   ┌── dim_produtos
                  │   │   │
                  ▼   ▼   ▼
              fct_nps_respostas   ◄── dim_canais
                  ▲   ▲
                  │   │
      dim_colaboradores  (regra_nps → classificação)
```

**Métrica principal:** NPS = %Promotores − %Detratores
(Detrator = nota 0–6, Neutro = 7–8, Promotor = 9–10)

---

## Conceitos-chave do dbt (leitura de 2 min antes de começar)

- **source**: uma tabela crua que já existe no warehouse. Você a declara num `.yml` e a
  referencia com `{{ source('nps_raw', 'respostas_nps') }}`.
- **model**: um arquivo `.sql` com um `SELECT`. O dbt cria uma view/tabela a partir dele.
- **`ref()`**: como um modelo aponta para outro — `{{ ref('stg_respostas_nps') }}`. É isso
  que monta o DAG (grafo de dependências) automaticamente.
- **materialization**: como o modelo vira objeto no banco. `view` (leve, recalcula na hora)
  ou `table` (materializa de fato). Staging costuma ser view; marts, table.
- **seed**: um CSV pequeno versionado no repositório que o dbt carrega com `dbt seed`.
  Ótimo para tabelas de regra/lookup (ex.: `regra_nps`).
- **test**: uma asserção sobre os dados (unique, not_null, relationships…). Roda com `dbt test`.
- **staging vs marts**: staging = 1 modelo por tabela de origem, só limpa/renomeia/casteia
  (sem join). marts = modelos de negócio (dimensões e fatos), aqui entram os joins.

---

## Fase 1 — Ambiente (~30 min, faz uma vez)

> Notebook do trabalho: se o BigQuery que você tem é o da empresa, crie um **dataset
> separado** só seu (ex.: `nps_raw`, `dbt_seunome`) para não misturar com produção — e,
> se for política da empresa, confirme com seu time antes de subir os CSVs.

**1.1 Python** (precisa 3.9+):
```bash
python3 --version
```

**1.2 Ambiente virtual + dbt para BigQuery:**
```bash
mkdir nps-analytics && cd nps-analytics
python3 -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
python -m pip install --upgrade pip wheel setuptools
pip install dbt-bigquery         # já traz o dbt-core junto
dbt --version
```

**1.3 Git + GitHub:**
```bash
git --version                    # se não tiver, instale o Git
# crie uma conta em github.com e um repositório vazio chamado "nps-analytics"
```

**1.4 Google Cloud + BigQuery:**
1. Acesse console.cloud.google.com e crie (ou selecione) um **projeto** GCP. Anote o
   **Project ID**.
2. Se for conta pessoal sem faturamento, o **BigQuery sandbox** é grátis (limites de
   1 TB de consulta/mês e 10 GB de storage — sobra muito para esse volume).
3. Instale o `gcloud` CLI (cloud.google.com/sdk) e autentique para o dbt usar:
```bash
gcloud auth application-default login
```
Isso deixa o dbt logar no BigQuery com sua própria conta (método `oauth`, o mais simples
para desenvolver local).

---

## Fase 2 — Dados brutos no BigQuery (~20 min)

Você recebeu 8 CSVs na pasta `nps_raw_csv/`. Eles estão **sujos de propósito** — não limpe
nada aqui; a limpeza é trabalho do dbt.

**2.1 Crie o dataset cru** no BigQuery (Console → BigQuery → seu projeto → *Create dataset*):
- Dataset ID: `nps_raw`
- Location: **`US`** (guarde esse valor — o `profiles.yml` precisa bater com ele)

**2.2 Suba cada CSV como uma tabela** (Console → dataset `nps_raw` → *Create table*):
- Source: *Upload* → escolha o CSV
- Table name: mesmo nome do arquivo (`respostas_nps`, `clientes`, `produtos`, `canais`,
  `colaboradores`, `calendario`, `regra_nps`)
- Schema: **Auto-detect** ligado
- ⚠️ Importante: em *Advanced options*, deixe o tipo das colunas como **STRING** sempre que
  possível (ou aceite o auto-detect e conserte no staging). Como `nota_nps` e `data_resposta`
  vêm sujas, você **quer** que cheguem como texto para limpar no dbt. Se o auto-detect
  reclamar, marque "*Allow quoted newlines*" e defina header rows = 1.

**2.3 Confirme:** no editor de query do BigQuery:
```sql
SELECT COUNT(*) FROM `SEU_PROJETO.nps_raw.respostas_nps`;   -- deve dar 632
```

---

## Fase 3 — Inicializar o projeto dbt (~15 min)

**3.1 Crie o projeto** (de dentro de `nps-analytics/`, com a venv ativa):
```bash
dbt init nps_telecom
```
Responda: adapter = **bigquery**, method = **oauth**, project = **SEU_PROJETO**,
dataset = **dbt_seunome**, threads = **4**, location = **US**.

Isso grava um `~/.dbt/profiles.yml` assim:
```yaml
nps_telecom:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: oauth
      project: SEU_PROJETO          # seu Project ID do GCP
      dataset: dbt_seunome          # onde o dbt vai CRIAR os modelos
      location: US                  # tem que bater com o dataset nps_raw
      threads: 4
      timeout_seconds: 300
```

**3.2 Teste a conexão:**
```bash
cd nps_telecom
dbt debug        # tem que dar "All checks passed!"
```

**3.3 Estrutura de pastas** dentro de `models/`:
```
models/
├── staging/
│   ├── _sources.yml
│   ├── _staging.yml
│   ├── stg_respostas_nps.sql
│   ├── stg_clientes.sql
│   ├── stg_produtos.sql
│   ├── stg_canais.sql
│   ├── stg_colaboradores.sql
│   └── stg_calendario.sql
└── marts/
    ├── _marts.yml
    ├── dim_clientes.sql
    ├── dim_produtos.sql
    ├── dim_canais.sql
    ├── dim_colaboradores.sql
    ├── dim_calendario.sql
    ├── fct_nps_respostas.sql
    └── mart_nps_resumo.sql
```
Pode apagar a pasta `models/example/` que vem no template.

**3.4 Declare as sources** em `models/staging/_sources.yml`:
```yaml
version: 2
sources:
  - name: nps_raw
    database: SEU_PROJETO       # Project ID
    schema: nps_raw             # o dataset cru
    tables:
      - name: respostas_nps
      - name: clientes
      - name: produtos
      - name: canais
      - name: colaboradores
      - name: calendario
      - name: regra_nps
```

---

## Fase 4 — Staging: a limpeza (o coração do projeto)

Regra do staging: **1 modelo por origem, sem join, materializado como view**. Aqui você
resolve TODA a sujeira. Configure a pasta como view no `dbt_project.yml`:
```yaml
models:
  nps_telecom:
    staging:
      +materialized: view
    marts:
      +materialized: table
```

**`models/staging/stg_respostas_nps.sql`** — o modelo mais importante. Cada bloco abaixo
resolve um problema real que achamos na base:

```sql
with fonte as (
    select * from {{ source('nps_raw', 'respostas_nps') }}
),

limpo as (
    select
        -- chave normalizada (tira espaços; deixa maiúscula)
        upper(trim(id_resposta))                              as id_resposta,

        -- chave do cliente: 'cli0035', ' CLI0108' -> 'CLI0035'
        upper(trim(id_cliente))                               as id_cliente,
        upper(trim(id_colaborador))                           as id_colaborador,

        -- data: aceita dd/mm/aaaa; '2026-13-02', 'não informado' viram NULL
        safe.parse_date('%d/%m/%Y', trim(data_resposta))      as data_resposta,

        -- nota: tira espaço, troca vírgula por ponto, castea; texto vira NULL
        safe_cast(replace(trim(nota_nps), ',', '.') as float64) as nota_num,

        -- canal padronizado (junta as variações de escrita)
        case
            when lower(trim(canal)) in ('call center','callcenter') then 'Call Center'
            when lower(trim(canal)) in ('whatsapp','wpp')            then 'WhatsApp'
            when lower(trim(canal)) in ('loja','loja física')        then 'Loja'
            when lower(trim(canal)) in ('app','app minha tcm')       then 'App Minha TCM'
            when lower(trim(canal)) = 'e-mail'                       then 'E-mail'
            when lower(trim(canal)) = 'pesquisa pós-atendimento'     then 'Pesquisa Pós-Atendimento'
            else initcap(trim(canal))
        end                                                   as canal,

        initcap(trim(produto))                                as produto,
        initcap(trim(jornada))                                as jornada,

        -- cidade padronizada (Assu/Açu/ACU -> Assu; caixa alta -> normal)
        case
            when upper(trim(cidade_respondida)) in ('ASSU','AÇU','ACU') then 'Assu'
            when upper(trim(cidade_respondida)) like 'NISIA%'           then 'Nísia Floresta'
            when upper(trim(cidade_respondida)) like 'PAU DOS FERROS%'  then 'Pau dos Ferros'
            else initcap(trim(cidade_respondida))
        end                                                   as cidade,

        trim(motivo_principal)                                as motivo_principal,
        trim(comentario)                                      as comentario,
        trim(status_registro)                                 as status_registro
    from fonte
),

final as (
    select
        id_resposta,
        id_cliente,
        id_colaborador,
        data_resposta,
        -- só aceita nota inteira de 0 a 10; resto vira NULL (fora do cálculo do NPS)
        case when nota_num between 0 and 10 and mod(nota_num, 1) = 0
             then cast(nota_num as int64) end                 as nota_nps,
        canal, produto, jornada, cidade,
        motivo_principal, comentario, status_registro
    from limpo
    -- mantém só registros válidos (tira Teste, Duplicado, Cancelado)
    where status_registro = 'Válido'
    -- remove id_resposta duplicado, ficando com 1 por chave
    qualify row_number() over (
        partition by id_resposta order by data_resposta desc
    ) = 1
)

select * from final
```

Os demais staging são simples (trim nas chaves e renomear). Exemplo
**`stg_clientes.sql`**:
```sql
with fonte as (select * from {{ source('nps_raw', 'clientes') }})
select
    upper(trim(id_cliente))            as id_cliente,
    trim(nome_cliente)                 as nome_cliente,
    initcap(trim(cidade))              as cidade,
    upper(trim(uf))                    as uf,
    trim(segmento)                     as segmento,
    safe.parse_date('%d/%m/%Y', trim(data_ativacao)) as data_ativacao,
    trim(plano)                        as plano,
    trim(status_cliente)               as status_cliente
from fonte
qualify row_number() over (partition by upper(trim(id_cliente)) order by nome_cliente) = 1
```
Replique a ideia para `produtos`, `canais`, `colaboradores`, `calendario`.

Rode e confira:
```bash
dbt run --select staging
```

---

## Fase 5 — Regra de negócio como seed

Copie `regra_nps.csv` para `seeds/regra_nps.csv` no projeto e rode:
```bash
dbt seed
```
Agora `{{ ref('regra_nps') }}` te dá o mapa nota → classificação. (Alternativa: fazer a
classificação direto num `CASE` no fato — mais simples, mas o seed ensina o recurso e deixa
a regra versionada e auditável.)

---

## Fase 6 — Marts: modelagem dimensional

**Dimensões** = staging renomeado com prefixo de chave. Ex. **`dim_clientes.sql`**:
```sql
select
    id_cliente,
    nome_cliente,
    cidade      as cidade_cliente,
    uf,
    segmento,
    plano,
    status_cliente,
    data_ativacao
from {{ ref('stg_clientes') }}
```

**Fato** **`fct_nps_respostas.sql`** (grão: 1 resposta válida), já com a classificação:
```sql
with respostas as (
    select * from {{ ref('stg_respostas_nps') }}
),
regra as (
    select cast(nota as int64) as nota, classificacao
    from {{ ref('regra_nps') }}
)
select
    r.id_resposta,
    r.data_resposta,
    r.id_cliente,
    r.id_colaborador,
    r.canal,
    r.produto,
    r.jornada,
    r.cidade,
    r.motivo_principal,
    r.nota_nps,
    g.classificacao                                   as classificacao_nps,
    -- flags úteis pro cálculo do NPS no BI
    if(g.classificacao = 'Promotor', 1, 0)            as is_promotor,
    if(g.classificacao = 'Detrator', 1, 0)            as is_detrator,
    if(g.classificacao = 'Neutro',   1, 0)            as is_neutro
from respostas r
left join regra g on r.nota_nps = g.nota
where r.nota_nps is not null      -- notas inválidas não entram no NPS
```

**Agregado** **`mart_nps_resumo.sql`** (NPS por mês/canal/produto, pronto pro dashboard):
```sql
select
    date_trunc(data_resposta, month)                  as mes,
    canal,
    produto,
    count(*)                                          as total_respostas,
    sum(is_promotor)                                  as promotores,
    sum(is_detrator)                                  as detratores,
    round(100.0 * (sum(is_promotor) - sum(is_detrator)) / count(*), 1) as nps
from {{ ref('fct_nps_respostas') }}
group by 1, 2, 3
```

```bash
dbt run        # roda tudo: staging + seed + marts
```

---

## Fase 7 — Testes (aqui o projeto ganha credibilidade)

Em **`models/marts/_marts.yml`**:
```yaml
version: 2
models:
  - name: fct_nps_respostas
    columns:
      - name: id_resposta
        tests: [unique, not_null]           # os 10 duplicados já foram tratados no staging
      - name: nota_nps
        tests:
          - not_null
          - accepted_values:
              values: [0,1,2,3,4,5,6,7,8,9,10]
      - name: classificacao_nps
        tests:
          - accepted_values:
              values: ['Detrator','Neutro','Promotor']
      - name: id_cliente
        tests:
          - relationships:                  # todo cliente do fato existe na dimensão?
              to: ref('dim_clientes')
              field: id_cliente
```
```bash
dbt test
```
Experimente também rodar os testes **contra a fonte crua** (declarando `unique`/`not_null`
em `id_resposta` no `_sources.yml`) e veja o teste **falhar** por causa dos duplicados —
depois passe pelo staging e veja passar. Esse contraste é ótimo pra explicar o valor do dbt.

---

## Fase 8 — Documentação e lineage

Adicione `description:` nos modelos e colunas nos `.yml` (aproveite os textos da aba
`Dicionario_Dados`). Depois:
```bash
dbt docs generate
dbt docs serve      # abre no navegador
```
No site gerado, clique no ícone de grafo (canto inferior direito) para ver o **DAG**:
`nps_raw → stg_* → dim_*/fct_* → mart_*`. Esse diagrama é ótimo pro README/portfólio.

---

## Fase 9 — Dashboard

Opção mais rápida e grátis: **Looker Studio** (lookerstudio.google.com) conecta direto no
BigQuery. Crie um relatório em cima de `mart_nps_resumo` e `fct_nps_respostas` com:
- NPS geral (número grande) e evolução mensal (linha)
- NPS por canal, por produto e por jornada (barras)
- Ranking de motivos dos detratores
- Mapa/tabela por cidade

Se preferir o que você já usa no trabalho, **Metabase** também conecta no BigQuery e roda os
mesmos modelos.

**Perguntas de negócio pra guiar as análises:**
1. Qual o NPS geral da operadora no período?
2. Qual canal entrega a pior experiência?
3. Qual jornada (Instalação, Cobrança, Suporte…) gera mais detratores?
4. O NPS está melhorando ou piorando mês a mês?
5. Existe cidade ou produto com NPS muito abaixo da média?

---

## Fase 10 — Git e portfólio

Crie um **`.gitignore`** na raiz:
```
target/
dbt_packages/
logs/
.venv/
```
Escreva um **`README.md`** curto: contexto do NPS, o diagrama do DAG, os problemas de
qualidade que você tratou, e as 3–4 principais descobertas. Então:
```bash
git init
git add .
git commit -m "Pipeline de NPS: dbt + BigQuery (staging, marts, testes, docs)"
git branch -M main
git remote add origin https://github.com/SEU_USUARIO/nps-analytics.git
git push -u origin main
```

---

## Checklist rápido

- [ ] venv + `dbt-bigquery` instalados; `dbt --version` ok
- [ ] `gcloud auth application-default login` feito
- [ ] dataset `nps_raw` criado e 7 CSVs carregados no BigQuery
- [ ] `dbt debug` → All checks passed
- [ ] `_sources.yml` declarado
- [ ] 6 modelos de staging rodando (`dbt run --select staging`)
- [ ] `dbt seed` (regra_nps)
- [ ] dimensões + `fct_nps_respostas` + `mart_nps_resumo` rodando
- [ ] `dbt test` passando (e o teste "que falha" na fonte crua, pra comparar)
- [ ] `dbt docs generate && dbt docs serve` → DAG visível
- [ ] dashboard no Looker Studio / Metabase
- [ ] repositório no GitHub com README

---

*Comandos dbt do dia a dia:* `dbt run` (constrói), `dbt test` (testa),
`dbt build` (run + test + seed na ordem do DAG), `dbt run --select stg_respostas_nps`
(roda só um modelo), `dbt docs serve` (documentação).
