-- Notificacoes dos agravos de saude do trabalhador no SINAN, decodificadas.
--
-- O SINAN e a notificacao do sistema de saude e alcanca quem a CAT nao
-- alcanca: o empregado sem carteira, o autonomo, o avulso. situacao_trabalho
-- e o campo que mostra isso, e cat_emitida mostra quanto do caso notificado
-- chegou tambem a Previdencia. Os codigos seguem o dicionario do SINAN; o
-- desfecho (EVOLUCAO) muda de significado entre agravos, e so o obito do
-- acidente grave (codigo 5) e decodificado. Da intoxicacao exogena entram so
-- os casos marcados como relacionados ao trabalho (DOENCA_TRA = 1), porque o
-- agravo inclui toda intoxicacao. A idade vem codificada: o primeiro digito
-- e a unidade (4 = anos) e os tres seguintes o valor. Os anos de PRELIM ainda
-- recebem notificacoes e nao se comparam com os FINAIS.
WITH base AS (
    SELECT
        agravo,
        CAST(ano AS INT) AS ano,
        situacao_dados,
        get_json_string(registro, '$.DT_NOTIFIC') AS dt_notific,
        get_json_string(registro, '$.SG_UF_NOT') AS uf_codigo,
        get_json_string(registro, '$.ID_MUNICIP') AS municipio_codigo,
        get_json_string(registro, '$.NU_IDADE_N') AS idade_codigo,
        get_json_string(registro, '$.CS_SEXO') AS sexo_codigo,
        get_json_string(registro, '$.CS_RACA') AS raca_codigo,
        get_json_string(registro, '$.ID_OCUPA_N') AS ocupacao,
        get_json_string(registro, '$.SIT_TRAB') AS sit_trab,
        get_json_string(registro, '$.CNAE') AS cnae,
        get_json_string(registro, '$.CAT') AS cat,
        get_json_string(registro, '$.EVOLUCAO') AS evolucao,
        get_json_string(registro, '$.DOENCA_TRA') AS doenca_tra
    FROM {{ source('bronze', 'sinan_trabalho') }}
)
SELECT
    b.agravo,
    CASE b.agravo
        WHEN 'ACGR' THEN 'Acidente de trabalho grave'
        WHEN 'ACBI' THEN 'Acidente com material biológico'
        WHEN 'LERD' THEN 'LER/DORT'
        WHEN 'MENT' THEN 'Transtornos mentais relacionados ao trabalho'
        WHEN 'PAIR' THEN 'Perda auditiva induzida por ruído'
        WHEN 'PNEU' THEN 'Pneumoconioses'
        WHEN 'DERM' THEN 'Dermatoses ocupacionais'
        WHEN 'CANC' THEN 'Câncer relacionado ao trabalho'
        WHEN 'IEXO' THEN 'Intoxicação exógena relacionada ao trabalho'
    END AS agravo_nome,
    b.ano,
    b.situacao_dados = 'PRELIM' AS preliminar,
    str_to_date(b.dt_notific, '%Y-%m-%d') AS data_notificacao,
    m.uf_nome AS uf,
    m.regiao,
    CASE WHEN left(b.idade_codigo, 1) = '4' THEN CAST(substr(b.idade_codigo, 2) AS INT) END AS idade,
    CASE b.sexo_codigo WHEN 'M' THEN 'Masculino' WHEN 'F' THEN 'Feminino' END AS sexo,
    CASE b.raca_codigo WHEN '1' THEN 'Branca' WHEN '2' THEN 'Preta' WHEN '3' THEN 'Amarela'
                       WHEN '4' THEN 'Parda' WHEN '5' THEN 'Indígena' END AS raca_cor,
    nullif(b.ocupacao, '') AS cbo_codigo,
    o.familia_titulo AS cbo_familia,
    CASE b.sit_trab
        WHEN '01' THEN 'Empregado com carteira'
        WHEN '02' THEN 'Empregado sem carteira'
        WHEN '03' THEN 'Autônomo ou conta própria'
        WHEN '04' THEN 'Servidor público estatutário'
        WHEN '05' THEN 'Servidor público celetista'
        WHEN '06' THEN 'Aposentado'
        WHEN '07' THEN 'Desempregado'
        WHEN '08' THEN 'Trabalho temporário'
        WHEN '09' THEN 'Cooperativado'
        WHEN '10' THEN 'Trabalhador avulso'
        WHEN '11' THEN 'Empregador'
        WHEN '12' THEN 'Outros'
    END AS situacao_trabalho,
    CASE
        WHEN b.sit_trab IN ('01', '04', '05') THEN 'formal'
        WHEN b.sit_trab IN ('02', '03', '08', '10') THEN 'informal'
        WHEN b.sit_trab IN ('06', '07', '09', '11', '12') THEN 'outra'
    END AS vinculo,
    nullif(b.cnae, '') AS cnae,
    CASE b.cat WHEN '1' THEN true WHEN '2' THEN false END AS cat_emitida,
    b.agravo = 'ACGR' AND b.evolucao = '5' AS obito_trabalho
FROM base b
LEFT JOIN {{ source('bronze', 'ibge_municipios') }} m
    ON m.codigo = left(b.municipio_codigo, 6)
LEFT JOIN {{ source('bronze', 'cbo') }} o
    ON o.codigo = b.ocupacao AND o.nivel = 'ocupacao'
WHERE b.agravo <> 'IEXO' OR b.doenca_tra = '1'
