with fonte as (select * from {{ source('nps_raw', 'regra_nps') }})
select
    safe_cast(nota as int64)   as nota,
    trim(classificacao)        as classificacao
from fonte