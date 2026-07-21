-- Dimensão de clientes: um registro por cliente único.
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