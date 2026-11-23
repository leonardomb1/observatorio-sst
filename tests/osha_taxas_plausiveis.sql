-- Falha se algum ano da OSHA tiver TRIR fora de 1 a 10 casos por 100 trabalhadores, DART maior que
-- o TRIR ou mais de 10% dos estabelecimentos excluidos: sinal de que voltaram declaracoes
-- implausiveis ou de que o filtro passou a cortar demais.
SELECT ano, trir, dart, estabelecimentos, estabelecimentos_excluidos
FROM {{ ref('gold__osha_eua_taxas_ano') }}
WHERE trir IS NULL
   OR trir NOT BETWEEN 1 AND 10
   OR dart > trir
   OR estabelecimentos_excluidos > 0.10 * (estabelecimentos + estabelecimentos_excluidos)
