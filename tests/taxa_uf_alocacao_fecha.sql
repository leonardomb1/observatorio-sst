-- Falha se a contagem de CAT alocadas a uma UF superar o total de CAT da
-- mesma UF, ou se o total do Brasil nao fechar com alocadas mais descartadas.
-- As duas contagens usam a mesma chave de UF; se a regra de uma mudar sem a
-- outra, CAT passariam a sumir ou a nascer entre o total e a taxa.
select 'uf' as nivel, ano, uf_sigla, cat_total, cat_alocadas, cat_descartadas
from {{ ref('gold__taxa_incidencia_uf') }}
where cat_descartadas < 0
   or cat_alocadas + cat_descartadas <> cat_total
union all
select 'brasil', ano, null, cat_total, cat_alocadas, cat_descartadas
from {{ ref('gold__taxa_incidencia_brasil') }}
where cat_descartadas < 0
   or cat_alocadas + cat_descartadas <> cat_total
