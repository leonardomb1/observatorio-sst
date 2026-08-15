-- Falha se o total do anuario nao fechar com a soma de com CAT e sem CAT, ou se
-- os motivos nao fecharem com o total de CAT registradas, com folga de 1% para
-- arredondamento da fonte. O extrator reconstroi o cabecalho a partir de celulas
-- mescladas espalhadas por tres linhas, e uma coluna atribuida ao grupo errado
-- produziria numeros plausiveis e silenciosamente trocados.
select ano, escopo, cnae_codigo, total, com_cat, sem_cat, tipico, trajeto, doenca
from {{ ref('gold__aeat_subnotificacao') }}
where cnae_codigo = 'TOTAL'
  and (abs(coalesce(com_cat, 0) + coalesce(sem_cat, 0) - total) > total * 0.01
       or abs(coalesce(tipico, 0) + coalesce(trajeto, 0) + coalesce(doenca, 0)
              - coalesce(com_cat, 0)) > coalesce(com_cat, 0) * 0.01)
