-- Falha se algum ano consolidado sair da faixa historica conhecida, entre 300
-- mil e 800 mil acidentes. Serve de rede contra carga parcial ou duplicada: um
-- ano com metade do volume normal costuma significar backfill interrompido, e
-- um ano inflado, arquivo cumulativo que escapou da deduplicacao.
select ano, cats
from {{ ref('gold__status_ano') }}
where ano_status = 'consolidado'
  and (cats < 300000 or cats > 800000)
