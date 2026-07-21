select
    data,
    ano,
    mes_numero,
    ano_mes,
    dia_semana
from {{ ref('stg_calendario') }}