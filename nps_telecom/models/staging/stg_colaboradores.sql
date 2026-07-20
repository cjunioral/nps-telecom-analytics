with fonte as (select * from {{ source('nps_raw', 'colaboradores') }})
select
    upper(trim(string_field_0))   as id_colaborador,
    trim(string_field_1)          as nome_colaborador,
    trim(string_field_2)          as area
from fonte
where string_field_0 != 'id_colaborador'