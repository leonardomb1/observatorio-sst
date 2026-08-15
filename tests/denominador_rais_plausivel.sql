-- Falha se o estoque de vinculos de um ano sair da faixa de 30 a 80 milhoes.
-- Esta e a rede contra o defeito que a fonte ja produziu: o FTP do PDET
-- interrompe a transferencia sem sinalizar erro, e um arquivo truncado gera um
-- denominador pequeno que inflaria todas as taxas do ano sem nenhum alarme.
select ano, sum(vinculos_ativos) as vinculos
from {{ ref('gold__vinculos_rais_municipio') }}
group by ano
having sum(vinculos_ativos) < 30000000 or sum(vinculos_ativos) > 80000000
