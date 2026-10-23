SELECT ano, mes, cats, obitos, arquivos, ref_mes, nivel_ano, razao_esperado, status_mes, nota
FROM {{ ref('gold__cobertura_cat_mensal') }}
