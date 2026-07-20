with fonte as (select * from {{ source('nps_raw', 'produtos') }})
select
    upper(trim(string_field_0))   as id_produto,
    trim(string_field_1)          as produto,
    trim(string_field_2)          as descricao
from fonte
where string_field_0 != 'id_produto'