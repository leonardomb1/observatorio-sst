-- Falha se o mesmo periodo aparecer com dois arquivos de origem distintos na
-- CAT, sintoma de carga repetida sem o DELETE previo por periodo.
select periodo, count(distinct arquivo_origem) as arquivos
from {{ source('silver', 'acidentes') }}
group by periodo
having count(distinct arquivo_origem) > 1
