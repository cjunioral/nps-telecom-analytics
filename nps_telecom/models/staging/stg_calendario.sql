with fonte as (select * from {{ source('nps_raw', 'calendario') }})
select
    -- Aceita dd/mm/aaaa e, por segurança, ISO (aaaa-mm-dd).
    coalesce(
        safe.parse_date('%d/%m/%Y', cast(data as string)),
        safe_cast(cast(data as string) as date)
    )                              as data,
    safe_cast(ano as int64)        as ano,
    safe_cast(mes_numero as int64) as mes_numero,
    cast(ano_mes as string)        as ano_mes,
    cast(dia_semana as string)     as dia_semana
from fonte
-- Dimensão de calendário exige data válida e única.
-- Descarta linhas com data inválida (ex.: '2026-13-02' -> null).
qualify data is not null
    and row_number() over (partition by data order by data) = 1