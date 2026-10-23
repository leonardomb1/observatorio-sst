-- Falha se a mesma CAT aparecer em mais de um arquivo depois da deduplicacao.
-- Os arquivos cumulativos da origem repetiriam a CAT e inflariam o ano.
select cat_chave, count(distinct periodo) as arquivos
from {{ ref('silver__acidentes') }}
group by cat_chave
having count(distinct periodo) > 1
