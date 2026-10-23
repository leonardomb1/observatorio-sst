-- Falha se o denominador sem administracao publica superar o total de
-- vinculos em algum municipio, ou se a soma anual sair de 20 a 60 milhoes
-- (variante sem as divisoes 84 a 88) e de 25 a 70 milhoes (sem a 84).
-- Fora dessas faixas, a subclasse CNAE da RAIS mudou de formato.
select 'municipio' as nivel, ano, municipio_codigo, vinculos_ativos, vinculos_sem_adm_publica
from {{ ref('gold__vinculos_rais_municipio') }}
where vinculos_sem_adm_publica > vinculos_ativos
   or vinculos_sem_divisoes_84_88 > vinculos_sem_adm_publica
union all
select 'ano', ano, null, sum(vinculos_ativos), sum(vinculos_sem_adm_publica)
from {{ ref('gold__vinculos_rais_municipio') }}
group by ano
having sum(vinculos_sem_adm_publica) not between 25000000 and 70000000
    or sum(vinculos_sem_divisoes_84_88) not between 20000000 and 60000000
