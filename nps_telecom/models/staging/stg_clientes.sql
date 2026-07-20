with fonte as (select * from {{ source('nps_raw', 'clientes') }})
select
    upper(trim(id_cliente))                            as id_cliente,
    trim(nome_cliente)                                 as nome_cliente,
    initcap(trim(cidade))                              as cidade,
    upper(trim(uf))                                    as uf,
    trim(segmento)                                     as segmento,
    cast(data_ativacao as date)                        as data_ativacao,
    trim(plano)                                        as plano,
    trim(status_cliente)                               as status_cliente
from fonte
qualify row_number() over (partition by upper(trim(id_cliente)) order by nome_cliente) = 1