-- Taxas anuais dos estabelecimentos dos EUA que enviam o formulario 300A a OSHA (Injury Tracking
-- Application): TRIR, casos registraveis por 200 mil horas (100 trabalhadores em tempo integral), e
-- DART, so os casos com afastamento, restricao ou transferencia.
--
-- O formulario traz erros de digitacao que, somados, derrubam a taxa: em 2019 as horas declaradas
-- somam trilhoes, e ha anos com bilhoes de empregados. Por isso numerador e horas das taxas vem so
-- dos estabelecimentos plausiveis, com 1 a 100 mil empregados e 500 a 4.000 horas por empregado no
-- ano; o filtro deixa de fora de 4% a 8% dos estabelecimentos e cerca de 2% a 3% dos casos. Mortes e
-- casos registraveis somam tudo o que foi reportado, pois nao dependem das horas.
WITH base AS (
    SELECT
        CAST(ano AS INT) AS ano,
        total_deaths,
        total_dafw_cases + total_djtr_cases + total_other_cases AS casos,
        total_dafw_cases + total_djtr_cases AS casos_dart,
        total_hours_worked AS horas,
        annual_average_employees BETWEEN 1 AND 100000
            AND total_hours_worked BETWEEN 500 * annual_average_employees
                AND 4000 * annual_average_employees AS plausivel
    FROM {{ source('bronze', 'osha_ita') }}
)
SELECT
    ano,
    SUM(total_deaths) AS mortes,
    SUM(casos) AS casos_registraveis,
    SUM(CASE WHEN plausivel THEN horas END) AS horas_trabalhadas,
    ROUND(SUM(CASE WHEN plausivel THEN casos END) * 200000.0
          / NULLIF(SUM(CASE WHEN plausivel THEN horas END), 0), 2) AS trir,
    ROUND(SUM(CASE WHEN plausivel THEN casos_dart END) * 200000.0
          / NULLIF(SUM(CASE WHEN plausivel THEN horas END), 0), 2) AS dart,
    SUM(CASE WHEN plausivel THEN 1 ELSE 0 END) AS estabelecimentos,
    SUM(CASE WHEN plausivel THEN 0 ELSE 1 END) AS estabelecimentos_excluidos
FROM base
GROUP BY ano
