select
    id_produto,
    produto,
    descricao as descricao_produto
from {{ ref('stg_produtos') }}