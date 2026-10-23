-- A media da renda mensal inicial ignora RMI zerada ou acima de 50 salarios
-- minimos, valores de preenchimento; rmi_n diz quantas concessoes entraram.
SELECT periodo, CAST(LEFT(periodo, 4) AS INT) AS ano, especie_codigo,
       CASE especie_codigo WHEN '91' THEN 'Auxílio-doença acidentário'
            WHEN '92' THEN 'Aposentadoria por invalidez acidentária'
            WHEN '93' THEN 'Pensão por morte acidentária'
            WHEN '94' THEN 'Auxílio-acidente' WHEN '95' THEN 'Auxílio suplementar'
            ELSE 'Outros' END AS especie,
       COUNT(*) AS concessoes,
       ROUND(AVG(CASE WHEN rmi_salarios_minimos > 0 AND rmi_salarios_minimos <= 50 THEN rmi_salarios_minimos END), 3) AS rmi_media,
       ROUND(percentile_approx(CASE WHEN rmi_salarios_minimos > 0 AND rmi_salarios_minimos <= 50 THEN rmi_salarios_minimos END, 0.5), 3) AS rmi_mediana,
       COUNT(CASE WHEN rmi_salarios_minimos > 0 AND rmi_salarios_minimos <= 50 THEN 1 END) AS rmi_n
FROM {{ ref('silver__beneficios_acidentarios') }}
WHERE acidente_trabalho
GROUP BY 1, 2, 3, 4
