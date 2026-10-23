-- familia e comparavel entre todas as geracoes de layout; detalhe e nulo onde
-- a origem cortou o texto em 20 caracteres e o corte e ambiguo. A coluna
-- parte_corpo repete a familia para os paineis que ja a consultam.
SELECT a.ano, a.familia, a.detalhe, a.familia AS parte_corpo, a.acidentes, a.obitos, s.ano_status, coalesce(s.ano_completo, false) AS ano_completo
FROM (
    SELECT ano, parte_corpo_familia AS familia, parte_corpo AS detalhe,
           COUNT(*) AS acidentes, SUM(obito) AS obitos
    FROM {{ ref('silver__acidentes') }}
    WHERE ano IS NOT NULL AND parte_corpo_familia IS NOT NULL
    GROUP BY 1, 2, 3
) a
LEFT JOIN {{ ref('gold__status_ano') }} s ON s.ano = a.ano
