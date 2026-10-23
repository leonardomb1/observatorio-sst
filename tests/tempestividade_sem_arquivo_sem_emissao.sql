-- Falha se o atraso medio de 2023 cair abaixo de 5 dias. Os arquivos de
-- 202306 a 202310 nao trazem data de emissao e a copiam do acidente; se
-- voltarem a entrar no calculo, o atraso do ano despenca para perto de zero.
select ano, sum(dias_medio_ate_emissao * registros) / sum(registros) as dias_medio
from {{ ref('gold__tempestividade_cat') }}
where ano = 2023 and dias_medio_ate_emissao is not null
group by ano
having sum(dias_medio_ate_emissao * registros) / sum(registros) < 5
