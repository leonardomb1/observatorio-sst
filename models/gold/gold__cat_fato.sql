{{ config(materialized='table', table_type='DUPLICATE', keys=['ano', 'mes'], distributed_by=['ano', 'mes']) }}
-- Acidentes com CAT, um registro por comunicacao, com as dimensoes que o site
-- recorta: UF e municipio do empregador, sexo, faixa etaria, atividade,
-- ocupacao, tipo, agente causador, natureza da lesao, parte do corpo, capitulo
-- e categoria da CID, mes e dia da semana.
--
-- Os recortes cruzados (lesao por setor, agente so nos obitos, municipio
-- dentro da UF) nao cabem num cubo pre-agregado sem multiplicar as linhas pelo
-- produto das dimensoes; agregar sobre o registro resolve qualquer
-- combinacao. Ficam de fora o CNPJ, a data de nascimento e as chaves de
-- arquivo: o fato tem so o que os microdados abertos ja permitem agregar.
SELECT
    a.ano,
    a.mes,
    dayofweek(a.data_acidente) AS dia_semana,
    s.ano_status,
    coalesce(s.ano_completo, false) AS ano_completo,
    u.uf_sigla,
    a.municipio_empregador_codigo AS municipio_codigo,
    a.sexo,
    {{ faixa_etaria('a.idade') }} AS faixa_etaria,
    {{ cnae_secao_da_divisao("left(lpad(a.cnae_codigo, 4, '0'), 2)") }} AS cnae_secao,
    left(lpad(a.cnae_codigo, 4, '0'), 2) AS cnae_divisao,
    {{ cbo_grande_grupo('a.cbo_codigo') }} AS cbo_grande_grupo,
    a.cbo_familia,
    a.tipo_acidente,
    coalesce(a.obito, false) AS obito,
    coalesce(a.covid, false) AS covid,
    a.agente_causador_familia AS agente_familia,
    a.agente_causador AS agente,
    a.natureza_lesao_familia AS natureza_familia,
    a.natureza_lesao AS natureza,
    a.parte_corpo_familia AS parte_familia,
    a.parte_corpo AS parte,
    a.cid10_capitulo,
    a.cid10_categoria,
    a.emitente_cat,
    a.dias_ate_emissao
FROM {{ ref('silver__acidentes') }} a
LEFT JOIN {{ ref('gold__dim_uf') }} u ON u.uf_nome = a.uf_empregador
LEFT JOIN {{ ref('gold__status_ano') }} s ON s.ano = a.ano
WHERE a.ano IS NOT NULL
