-- Resumo de NPS por mês, canal e produto. Tabela "servida" para o Power BI.
select
    date_trunc(data_resposta, month)            as mes,
    canal,
    produto,
    count(*)                                    as total_respostas,
    sum(is_promotor)                            as promotores,
    sum(is_neutro)                              as neutros,
    sum(is_detrator)                            as detratores,
    round(100.0 * (sum(is_promotor) - sum(is_detrator)) / count(*), 1) as nps
from {{ ref('fct_nps_respostas') }}
group by 1, 2, 3