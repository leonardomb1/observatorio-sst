-- Falha se algum agravo do SINAN tiver um ano sem notificacoes entre 2018 e
-- o ultimo ano carregado. Cada arquivo do DATASUS e um agravo-ano e chega
-- pelo FTP atraves do rele; um download interrompido apagaria o ano sem erro
-- na serie agregada.
with anos as (
    select agravo, ano, count(*) as notificacoes
    from {{ source('bronze', 'sinan_trabalho') }}
    group by agravo, ano
),
limites as (
    select agravo, count(distinct ano) as anos, max(ano) - 2018 + 1 as esperados
    from anos
    group by agravo
)
select agravo, anos, esperados
from limites
where anos < esperados
