with fonte as (select * from {{ source('nps_raw', 'canais') }})
select
    upper(trim(string_field_0))   as id_canal,
    trim(string_field_1)          as canal,
    trim(string_field_2)          as descricao
from fonte
-- A origem subiu com o cabeçalho como 1ª linha de dados; descarta.
where string_field_0 != 'id_canal'