-- Falha se a marca do rompimento de Brumadinho sair da faixa medida: 197
-- obitos e 45 CAT nao fatais com agente "Dique" no dia, 242 linhas. Fora da
-- faixa, a definicao do evento ou o layout do arquivo de 2019 mudou.
select count(*) as linhas
from {{ ref('silver__acidentes') }}
where evento_catastrofico = 'brumadinho_2019'
having count(*) not between 230 and 260
