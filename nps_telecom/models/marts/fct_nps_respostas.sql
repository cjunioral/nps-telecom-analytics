-- Tabela fato de NPS. Grão: uma linha por resposta válida.
-- Junta a classificação (Detrator/Neutro/Promotor) a partir da regra de negócio
-- e cria flags 0/1 para o cálculo do NPS no BI.

with respostas as (
    select * from {{ ref('stg_respostas_nps') }}
),

regra as (
    select nota, classificacao
    from {{ ref('stg_regra_nps') }}
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
    r.comentario,
    r.nota_nps,
    g.classificacao                             as classificacao_nps,
    -- Flags para o cálculo do NPS (NPS = %promotores - %detratores).
    if(g.classificacao = 'Promotor', 1, 0)      as is_promotor,
    if(g.classificacao = 'Neutro',   1, 0)      as is_neutro,
    if(g.classificacao = 'Detrator', 1, 0)      as is_detrator
from respostas r
left join regra g on r.nota_nps = g.nota
-- Notas inválidas (NULL) não entram no cálculo do NPS.
where r.nota_nps is not null
  -- Garante integridade referencial: descarta respostas cujo cliente não
  -- existe na dimensão (ex.: CLI9999, registro de teste injetado).
  and r.id_cliente in (select id_cliente from {{ ref('stg_clientes') }})