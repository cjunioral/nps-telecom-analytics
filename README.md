# 📊 Análise de NPS — Pipeline de Analytics Engineering (dbt + BigQuery + Power BI)

Projeto ponta a ponta de **analytics engineering**: da ingestão de dados brutos e
inconsistentes até um dashboard executivo interativo. Usa uma base de pesquisa de
**NPS (Net Promoter Score)** de uma operadora de telecomunicações.

> **Resumo:** transformei ~630 respostas de pesquisa cheias de inconsistências em um
> modelo dimensional confiável, testado e documentado, e construí um dashboard com dois
> temas dinâmicos que revela **onde** e **por que** o NPS está negativo.

---

## 🎯 Problema de negócio

A operadora coleta pesquisas de NPS em vários canais (Call Center, WhatsApp, App, Loja…),
mas os dados chegam inconsistentes e sem tratamento, impossibilitando uma leitura confiável.
As perguntas a responder:

- Qual o NPS geral e como ele evolui ao longo do tempo?
- Quais **canais**, **produtos** e **jornadas** puxam o indicador para baixo?
- Onde concentrar esforço de melhoria?

## 🧱 Arquitetura

```
CSV bruto (sujo) → BigQuery (raw) → dbt staging (limpa) → dbt marts (modela) → testes + docs → Power BI
```

Modelo dimensional em **star schema**: uma tabela fato de respostas de NPS ligada a
dimensões de clientes, produtos, canais, colaboradores e calendário.

## 🛠️ Stack

| Camada | Ferramenta |
|---|---|
| Ingestão / Data Warehouse | Google BigQuery |
| Transformação | dbt (dbt-core) |
| Testes e documentação | dbt tests + dbt docs |
| Versionamento | Git + GitHub (branches + Pull Requests) |
| Visualização | Power BI (visuais nativos + HTML/CSS/SVG customizados) |

## 🔍 Tratamento de qualidade de dado

A base foi construída com problemas típicos do mundo real. Cada um foi tratado na camada
correta do pipeline, e **os testes do dbt capturaram problemas que passariam despercebidos**
por filtros comuns:

- **Notas inválidas** — valores como `"sem nota"`, `"onze"`, `"10,0"` e `"11"` tratados e
  validados para a faixa 0–10.
- **Chaves inconsistentes** — `id_cliente` com espaços e caixa mista (`" CLI0108"`,
  `"cli0035"`) normalizadas para garantir joins confiáveis.
- **Datas impossíveis** — `"2026-13-02"` (mês 13) convertida para nulo com `SAFE.PARSE_DATE`.
- **Registros duplicados e órfãos** — `id_resposta` duplicados, uma resposta sem cliente e
  outra com cliente inexistente, todos capturados por testes `unique`, `not_null` e
  `relationships`.
- **Categorias inconsistentes** — variações de canal (`WhatsApp`/`WPP`/`whatsapp`) e de
  cidade (`Assu`/`Açu`/`ACU`) consolidadas.

**Resultado:** ~630 respostas brutas → **562 respostas válidas** e testadas.

## 📈 Principais achados

- **NPS geral: −9,4** (zona crítica; a escala vai de −100 a +100), com **tendência de piora**
  ao longo dos meses.
- A jornada de **Cobrança** e os canais de atendimento humano concentram a maior
  insatisfação.
- Um produto aparecia com NPS alto porém com **baixo volume de respostas** — sinalizado como
  amostra não representativa em vez de tratado como sucesso (rigor analítico).

## 🧱 Modelagem (dbt)

O projeto segue as convenções de camadas do dbt:

- **staging** — um modelo por fonte, responsável apenas por limpar, renomear e padronizar
  (sem joins). Materializado como *view*.
- **marts** — dimensões e tabela fato do modelo dimensional, mais um agregado de NPS por
  mês/canal/produto. Materializado como *table*.
- **seeds** — a regra de negócio do NPS (mapeia nota → Detrator/Neutro/Promotor).

Cobertura de testes: `unique`, `not_null`, `accepted_values` e `relationships` nas chaves e
métricas críticas. Documentação e *lineage graph* gerados com `dbt docs`.

## 🧪 Como rodar

```bash
# ambiente
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install dbt-bigquery

# autenticação no BigQuery
gcloud auth application-default login

# construir e testar o pipeline
cd nps_telecom
dbt build          # roda models + testes na ordem do DAG
dbt docs generate  # gera a documentação
dbt docs serve     # abre o lineage graph
```

## 📂 Estrutura do repositório

```
nps-telecom-analytics/
└── nps_telecom/            # projeto dbt
    ├── models/
    │   ├── staging/        # limpeza (1 modelo por origem) + testes
    │   └── marts/          # dimensões, fato e agregados + testes
    ├── seeds/              # regra de negócio do NPS
    └── dbt_project.yml
```

---

*Projeto de portfólio desenvolvido por [Cicero Junior](https://github.com/cjunioral).*
