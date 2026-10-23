-- Falha se a RMI media de alguma competencia e especie sair nula ou nao
-- positiva havendo concessoes com RMI valida, sinal de que a conversao do
-- texto da origem para numero deixou de funcionar.
select periodo, especie_codigo, rmi_media, rmi_n
from {{ ref('gold__beneficios_mensal') }}
where rmi_n > 0 and (rmi_media is null or rmi_media <= 0)
