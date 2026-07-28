-- Staging da dimensão de calendário.
-- Responsabilidade: converter a data para tipo DATE, derivar rótulos de
-- exibição e garantir chave válida e única (requisito de dimensão de data).

with fonte as (
    select * from {{ source('nps_raw', 'calendario') }}
),

convertido as (
    select
        -- A origem mistura formatos. Tenta dd/mm/aaaa primeiro e, se falhar,
        -- ISO (aaaa-mm-dd). SAFE evita que data inválida derrube o build:
        -- valores impossíveis (ex.: '2026-13-02', mês 13) viram NULL.
        coalesce(
            safe.parse_date('%d/%m/%Y', cast(data as string)),
            safe_cast(cast(data as string) as date)
        )                                        as data,
        safe_cast(ano as int64)                  as ano,
        safe_cast(mes_numero as int64)           as mes_numero,
        cast(ano_mes as string)                  as ano_mes,
        cast(dia_semana as string)               as dia_semana
    from fonte
),

final as (
    select
        data,
        ano,
        mes_numero,
        ano_mes,
        dia_semana,

        -- Rótulo curto para o eixo dos gráficos (ex.: 'jan/26').
        -- No Power BI, ordenar esta coluna por 'ano_mes' para não sair
        -- em ordem alfabética.
        format_date('%b/%y', data)               as mes_nome,

        -- Rótulo por extenso, útil em tooltips e títulos dinâmicos.
        format_date('%B de %Y', data)            as mes_nome_completo

    from convertido
    -- Uma dimensão de calendário exige data válida e única:
    --   - data nula quebraria o relacionamento 1:N com o fato no BI
    --   - data repetida invalidaria a cardinalidade "um" da dimensão
    qualify data is not null
        and row_number() over (partition by data order by data) = 1
)

select * from final