select
    id_canal,
    canal,
    descricao as descricao_canal
from {{ ref('stg_canais') }}