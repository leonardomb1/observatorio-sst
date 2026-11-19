-- Concessoes de beneficios por incapacidade, previdenciarios e acidentarios.
--
-- O ponto do modelo e a natureza do beneficio: o mesmo transtorno mental ou
-- a mesma lesao osteomuscular pode ser concedido como acidentario (B91, com
-- nexo reconhecido com o trabalho) ou como previdenciario (B31, sem nexo), e
-- a proporcao entre os dois mede quanto do adoecimento ligado ao trabalho a
-- Previdencia reconhece como tal.
--
-- Ate mai/2023 os arquivos trazem so o rotulo da especie, e a partir de
-- jun/2023 tambem o codigo; o codigo e derivado do rotulo quando falta, com
-- as regras especificas antes da generica, porque "Auxilio Doenca
-- Previdenciario" tambem contem "previdenci", que sozinho identifica a
-- especie 36. O layout de out/2026 grava o codigo com zero a esquerda (031),
-- normalizado aqui para o mesmo formato dos anteriores. Ano e mes saem por
-- aritmetica sobre o periodo: agrupar por CAST(left(periodo, 4)) devolve
-- chaves erradas no StarRocks, porque periodo e a chave de distribuicao. A CNAE so existe nos arquivos de jun/2023 em diante, como
-- classe de cinco digitos com o verificador, e vem zerada na grande maioria
-- das concessoes; cnae_classe e nula nesses casos.
--
-- O CID chega em tres formas: so o codigo, codigo e descricao no mesmo campo
-- (2022, "S42.0 Frat da Clavicula") e marcadores que nao sao diagnostico
-- ("Em Branco", "Zerados", "000000", "{n class}"). Fica so o codigo valido;
-- o resto vira nulo. Em 2022 a fonte omitiu o CID da maior parte dos
-- beneficios previdenciarios, e por isso a cobertura de CID de cada ano e
-- exposta no ouro.
WITH classificado AS (
    SELECT
        periodo,
        CASE
            WHEN CAST(CAST(nullif(trim(especie_codigo), '') AS INT) AS VARCHAR)
                 IN ('31', '32', '36', '91', '92', '93', '94', '95')
                THEN CAST(CAST(trim(especie_codigo) AS INT) AS VARCHAR)
            WHEN lower(especie) LIKE '%doen%previdenci%' THEN '31'
            WHEN lower(especie) LIKE '%invalidez%previdenci%' THEN '32'
            WHEN lower(especie) LIKE '%previdenci%' THEN '36'
            WHEN lower(especie) LIKE '%doen%acidente%' THEN '91'
            WHEN lower(especie) LIKE '%invalidez%acident%' THEN '92'
            WHEN lower(especie) LIKE '%pens%morte%acident%' THEN '93'
            WHEN lower(especie) LIKE '%suplementar%acident%' THEN '95'
            WHEN lower(especie) LIKE '%aux%acident%' THEN '94'
        END AS especie_codigo,
        trim(especie) AS especie,
        nullif(regexp_extract(upper(replace(trim(cid_codigo), '.', '')),
                              '^[A-Z][0-9]{2}[0-9]?', 0), '') AS cid10_codigo,
        nullif(trim(sexo), '') AS sexo,
        nullif(trim(uf), '') AS uf,
        nullif(nullif(trim(cnae_codigo), ''), '0') AS cnae_codigo,
        concessoes,
        soma_qt_sm_rmi
    FROM {{ source('bronze', 'inss_incapacidade') }}
)
SELECT
    periodo,
    CAST(periodo AS INT) DIV 100 AS ano,
    CAST(periodo AS INT) % 100 AS mes,
    especie_codigo,
    especie,
    CASE WHEN especie_codigo IN ('91', '92', '93', '94', '95') THEN 'acidentaria'
         WHEN especie_codigo IN ('31', '32', '36') THEN 'previdenciaria' END AS natureza,
    CASE WHEN especie_codigo IN ('31', '91') THEN 'temporaria'
         WHEN especie_codigo IN ('32', '92') THEN 'permanente'
         WHEN especie_codigo IN ('36', '94') THEN 'auxilio_acidente'
         ELSE 'outra' END AS tipo_incapacidade,
    cid10_codigo,
    left(cid10_codigo, 3) AS cid10_categoria,
    CASE
        WHEN cid10_codigo LIKE 'F%' THEN 'Transtornos mentais e comportamentais'
        WHEN cid10_codigo LIKE 'M%' THEN 'Doenças osteomusculares'
        WHEN cid10_codigo LIKE 'S%' OR cid10_codigo LIKE 'T%' THEN 'Lesões e envenenamentos'
        WHEN cid10_codigo IS NULL THEN NULL
        ELSE 'Demais diagnósticos'
    END AS grupo_cid,
    sexo,
    uf,
    left(lpad(cnae_codigo, 5, '0'), 4) AS cnae_classe,
    concessoes,
    soma_qt_sm_rmi
FROM classificado
