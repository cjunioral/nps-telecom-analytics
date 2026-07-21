select
    id_colaborador,
    nome_colaborador,
    area
from {{ ref('stg_colaboradores') }}