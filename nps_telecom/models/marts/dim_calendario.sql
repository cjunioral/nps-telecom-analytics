-- Dimensão de calendário: um registro por data válida.
-- Serve como tabela de datas do modelo no Power BI (marcar como
-- "tabela de data" e ordenar mes_nome por ano_mes).
select
    data,
    ano,
    mes_numero,
    ano_mes,
    mes_nome,
    mes_nome_completo,
    dia_semana
from {{ ref('stg_calendario') }}