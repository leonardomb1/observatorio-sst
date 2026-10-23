-- Falha se a grade de cobertura repetir ano e mes, o que duplicaria a soma
-- de CAT no status do ano.
select ano, mes, count(*) as linhas
from {{ ref('gold__cobertura_cat_mensal') }}
group by ano, mes
having count(*) > 1
