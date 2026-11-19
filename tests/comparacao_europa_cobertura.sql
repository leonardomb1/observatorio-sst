-- Falha se, em algum ano consolidado, menos de 80 divisoes de atividade
-- casarem entre CNAE e NACE. A juncao depende de extrair os dois digitos do
-- codigo NACE ('C16' vira '16'); uma mudanca no formato do Eurostat faria a
-- comparacao encolher sem erro nenhum.
select ano, count(*) as divisoes
from {{ ref('gold__comparacao_setorial_europa') }}
group by ano
having count(*) < 80
