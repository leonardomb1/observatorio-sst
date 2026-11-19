-- Obitos por causas externas do SIM, com os codigos decodificados.
--
-- O SIM e o registro de obitos do sistema de saude e nao depende da
-- Previdencia: alcanca a morte no trabalho do informal, do autonomo e do
-- servidor, que nunca geram CAT. O campo acidtrab, porem, so e de
-- preenchimento esperado nas causas externas e fica em branco na maior parte
-- delas; situacao_acidtrab separa o sim, o nao, o ignorado e o nao
-- preenchido, porque a contagem de obitos de trabalho do SIM e, ela tambem,
-- um piso, e o tamanho desse piso depende de quanto o campo foi preenchido.
--
-- A idade vem codificada: o primeiro digito e a unidade (4 anos, 5 mais de
-- cem anos, menores de um ano nas demais) e os dois seguintes o valor.
-- A UF e a do municipio de ocorrencia, que e onde o acidente aconteceu.
-- O campo de ocupacao usa a CBO 2002 e, para quem nao tinha ocupacao, codigos
-- proprios do SIM (999991 a 999995, e 998999 para ignorada), que viram
-- condicao_sem_ocupacao; codigos com cinco digitos perderam o zero a esquerda.
SELECT
    s.ano AS ano_arquivo,
    str_to_date(s.dtobito, '%d%m%Y') AS data_obito,
    CAST(right(s.dtobito, 4) AS INT) AS ano,
    CASE
        WHEN left(s.idade, 1) = '4' THEN CAST(right(s.idade, 2) AS INT)
        WHEN left(s.idade, 1) = '5' THEN 100 + CAST(right(s.idade, 2) AS INT)
        WHEN left(s.idade, 1) IN ('0', '1', '2', '3') THEN 0
    END AS idade,
    CASE s.sexo WHEN '1' THEN 'Masculino' WHEN '2' THEN 'Feminino' END AS sexo,
    CASE s.racacor WHEN '1' THEN 'Branca' WHEN '2' THEN 'Preta' WHEN '3' THEN 'Amarela'
                   WHEN '4' THEN 'Parda' WHEN '5' THEN 'Indígena' END AS raca_cor,
    CASE WHEN s.ocup NOT IN ('', '998999') AND s.ocup NOT LIKE '99999%'
         THEN lpad(s.ocup, 6, '0') END AS cbo_codigo,
    o.titulo AS cbo_titulo,
    o.familia_titulo AS cbo_familia,
    CASE s.ocup
        WHEN '999991' THEN 'Estudante'
        WHEN '999992' THEN 'Dona(o) de casa'
        WHEN '999993' THEN 'Aposentado ou pensionista'
        WHEN '999994' THEN 'Desempregado'
        WHEN '999995' THEN 'Presidiário'
    END AS condicao_sem_ocupacao,
    s.codmunocor AS municipio_ocorrencia_codigo,
    m.uf_nome AS uf_ocorrencia,
    m.regiao AS regiao_ocorrencia,
    s.causabas AS cid10_causa,
    CASE
        WHEN s.causabas BETWEEN 'V01' AND 'V89Z' THEN 'Trânsito'
        WHEN s.causabas BETWEEN 'V90' AND 'V99Z' THEN 'Outros transportes'
        WHEN s.causabas BETWEEN 'W00' AND 'W19Z' THEN 'Quedas'
        WHEN s.causabas BETWEEN 'W20' AND 'W49Z' THEN 'Forças mecânicas inanimadas'
        WHEN s.causabas BETWEEN 'W85' AND 'W99Z' THEN 'Corrente elétrica, radiação e temperatura'
        WHEN s.causabas BETWEEN 'X00' AND 'X19Z' THEN 'Fogo e calor'
        WHEN s.causabas BETWEEN 'X40' AND 'X49Z' THEN 'Intoxicações'
        WHEN s.causabas BETWEEN 'X60' AND 'X84Z' THEN 'Lesões autoprovocadas'
        WHEN s.causabas BETWEEN 'X85' AND 'Y09Z' THEN 'Agressões'
        ELSE 'Outras causas externas'
    END AS grupo_causa,
    CASE s.circobito WHEN '1' THEN 'Acidente' WHEN '2' THEN 'Suicídio'
                     WHEN '3' THEN 'Homicídio' WHEN '4' THEN 'Outro' END AS circunstancia,
    CASE s.acidtrab
        WHEN '1' THEN 'sim'
        WHEN '2' THEN 'nao'
        WHEN '9' THEN 'ignorado'
        ELSE 'nao_preenchido'
    END AS situacao_acidtrab,
    s.acidtrab = '1' AS acidente_trabalho
FROM {{ source('bronze', 'sim_causas_externas') }} s
LEFT JOIN {{ source('bronze', 'ibge_municipios') }} m
    ON m.codigo = left(s.codmunocor, 6)
LEFT JOIN {{ source('bronze', 'cbo') }} o
    ON o.codigo = lpad(s.ocup, 6, '0') AND o.nivel = 'ocupacao'
