-- Staging da tabela fato (pesquisas de NPS).
-- Responsabilidade desta camada: limpar/padronizar SEM fazer join.
-- Toda a sujeira da origem é tratada aqui para o mart receber dado confiável.

with fonte as (
    select * from {{ source('nps_raw', 'respostas_nps') }}
),

limpo as (
    select
        -- Chaves: origem vem com espaço e caixa mista (' CLI0108', 'cli0035').
        -- Normalizamos para o join com as dimensões não quebrar.
        upper(trim(id_resposta))                                 as id_resposta,
        upper(trim(id_cliente))                                  as id_cliente,
        upper(trim(id_colaborador))                              as id_colaborador,

        -- Data: formato dd/mm/aaaa. Valores inválidos ('2026-13-02',
        -- 'não informado') viram NULL via SAFE — não derrubam o build.
        safe.parse_date('%d/%m/%Y', trim(data_resposta))         as data_resposta,

        -- Nota: origem tem espaço (' 10'), vírgula decimal ('10,0') e
        -- texto ('sem nota','erro','onze'). Tratamos como float aqui;
        -- a validação de faixa/inteiro fica no bloco final.
        safe_cast(replace(trim(nota_nps), ',', '.') as float64)  as nota_num,

        -- Canal: consolida variações de escrita para o valor canônico.
        case
            when lower(trim(canal)) in ('call center','callcenter') then 'Call Center'
            when lower(trim(canal)) in ('whatsapp','wpp')           then 'WhatsApp'
            when lower(trim(canal)) in ('loja','loja física')       then 'Loja'
            when lower(trim(canal)) in ('app','app minha tcm')      then 'App Minha TCM'
            when lower(trim(canal)) = 'e-mail'                      then 'E-mail'
            when lower(trim(canal)) = 'pesquisa pós-atendimento'    then 'Pesquisa Pós-Atendimento'
            else initcap(trim(canal))
        end                                                      as canal,

        initcap(trim(produto))                                   as produto,
        initcap(trim(jornada))                                   as jornada,

        -- Cidade: mesma cidade aparece com grafias diferentes
        -- (Assu/Açu/ACU, NISIA FLORESTA...). Mapeamento pragmático;
        -- em produção viraria uma seed de-para de municípios.
        case
            when upper(trim(cidade_respondida)) in ('ASSU','AÇU','ACU') then 'Assu'
            when upper(trim(cidade_respondida)) like 'N%SIA%'           then 'Nísia Floresta'
            when upper(trim(cidade_respondida)) like 'PAU DOS FERROS%'  then 'Pau dos Ferros'
            else initcap(trim(cidade_respondida))
        end                                                      as cidade,

        trim(motivo_principal)                                   as motivo_principal,
        trim(comentario)                                         as comentario,
        trim(status_registro)                                    as status_registro
    from fonte
),

final as (
    select
        id_resposta,
        id_cliente,
        id_colaborador,
        data_resposta,
        -- Só nota inteira de 0 a 10 é válida; o resto vira NULL e fica
        -- de fora do cálculo do NPS (regra do dicionário de dados).
        case
            when nota_num between 0 and 10 and nota_num = trunc(nota_num)
            then cast(nota_num as int64)
        end                                                      as nota_nps,
        canal, produto, jornada, cidade,
        motivo_principal, comentario, status_registro
    from limpo
    -- Mantém só registros válidos (remove Teste, Duplicado, Cancelado).
    where status_registro = 'Válido'
    -- Deduplica id_resposta (a origem tem 10 duplicados reais).
    qualify row_number() over (
        partition by id_resposta order by data_resposta desc
    ) = 1
)

select * from final