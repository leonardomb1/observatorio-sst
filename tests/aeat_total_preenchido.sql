-- Falha se a linha TOTAL de qualquer recorte vier sem incidencia ou sem
-- mortalidade. Nas linhas de CNAE o nulo e esperado, porque a fonte grafa "-"
-- para classe sem ocorrencia, mas o TOTAL de um estado nunca e vazio: se
-- estiver, o cabecalho foi reconstruido na posicao errada e as colunas
-- inteiras sairam deslocadas.
select ano, escopo, incidencia_por_mil, mortalidade_por_100mil
from {{ ref('gold__aeat_indicadores_cnae') }}
where cnae_codigo = 'TOTAL'
  and (incidencia_por_mil is null or mortalidade_por_100mil is null)
