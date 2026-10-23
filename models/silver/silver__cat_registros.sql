{{ config(materialized='table', table_type='DUPLICATE', keys=['periodo'], distributed_by=['periodo']) }}
-- Uma linha por linha do bronze, com limpeza e marcas. O bronze guarda cada
-- arquivo como publicado; os defeitos de origem sao medidos por arquivo, e nao
-- fixados por periodo, para que defeito novo apareca nas marcas e nos testes.
WITH bruto AS (
    SELECT
        c.*,
        CASE WHEN c.periodo <= '202012' THEN 'A'
             WHEN c.periodo <= '202305' THEN 'B'
             WHEN c.periodo <= '202310' THEN 'D'
             ELSE 'C' END AS geracao,
        str_to_date(nullif(nullif(trim(c.data_acidente),'0000/00'),'00/00/0000'), '%d/%m/%Y') AS dt_acidente,
        str_to_date(nullif(nullif(trim(c.data_emissao_cat),'0000/00'),'00/00/0000'), '%d/%m/%Y') AS dt_emissao_origem,
        str_to_date(nullif(trim(c.data_nascimento),'00/00/0000'), '%d/%m/%Y') AS dt_nascimento,
        nullif(nullif(replace(trim(c.cid10_codigo),'.',''),'{ñ class}'),'') AS cid_bruto,
        nullif(trim(c.agente_causador),'{ñ class}') AS agente_texto,
        nullif(trim(c.parte_corpo),'{ñ class}') AS parte_texto,
        nullif(trim(c.natureza_lesao),'{ñ class}') AS natureza_texto
    FROM {{ source('bronze', 'cat') }} c
),
arquivo AS (
    SELECT
        periodo,
        avg(CASE WHEN dt_emissao_origem = dt_acidente THEN 1 ELSE 0 END) >= 0.95 AS emissao_copia_acidente,
        count(DISTINCT day(dt_emissao_origem)) = 1 AND count(*) > 50 AS emissao_dia_unico,
        avg(CASE WHEN cid_bruto REGEXP '(NULL|NUL|NU)$' THEN 1 ELSE 0 END) >= 0.5 AS cid_corrompido,
        avg(CASE WHEN cid_bruto IS NULL THEN 1 ELSE 0 END) >= 0.95 AS cid_ausente
    FROM bruto
    GROUP BY periodo
),
limpo AS (
    SELECT
        b.*,
        a.emissao_copia_acidente,
        a.emissao_dia_unico,
        a.cid_corrompido,
        a.cid_ausente,
        NOT (a.emissao_copia_acidente OR a.emissao_dia_unico) AS emissao_confiavel,
        -- 202507 completa o codigo com um NULL truncado
        regexp_replace(b.cid_bruto, '(NULL|NUL|NU)$', '') AS cid_limpo,
        -- o rotulo chega cortado em 20 caracteres fora da geracao B, e o corte
        -- perde o espaco final; os dois lados da juncao sao normalizados igual
        rtrim(left(b.agente_texto, 20)) AS agente_prefixo,
        rtrim(left(b.parte_texto, 20)) AS parte_prefixo,
        rtrim(left(b.natureza_texto, 20)) AS natureza_prefixo,
        nullif(split_part(trim(b.municipio_empregador),'-',1),'000000') AS municipio_codigo,
        nullif(nullif(trim(b.uf_empregador),'Zerado'),'{ñ class}') AS uf_emp,
        nullif(trim(b.cbo_codigo),'{ñ class}') AS cbo_limpo,
        nullif(trim(b.cnae_codigo),'0000') AS cnae_limpo,
        nullif(nullif(trim(b.sexo),'Não Informado'),'Indeterminado') AS sexo_limpo,
        nullif(trim(b.tipo_acidente),'Ignorado') AS tipo_limpo,
        (trim(b.indica_obito) = 'Sim') AS obito_limpo
    FROM bruto b
    JOIN arquivo a ON a.periodo = b.periodo
),
registros AS (
    SELECT
        l.periodo,
        l.arquivo_origem,
        l.geracao,
        l.dt_acidente AS data_acidente,
        CAST(year(l.dt_acidente) AS INT) AS ano,
        CAST(month(l.dt_acidente) AS INT) AS mes,
        CASE WHEN l.emissao_confiavel THEN l.dt_emissao_origem END AS data_emissao_cat,
        l.dt_emissao_origem AS data_emissao_cat_origem,
        l.emissao_confiavel,
        datediff(CASE WHEN l.emissao_confiavel THEN l.dt_emissao_origem END, l.dt_acidente) AS dias_ate_emissao,
        floor(datediff(l.dt_acidente, l.dt_nascimento) / 365.25) AS idade,
        nullif(nullif(trim(l.uf_acidente),'Zerado'),'{ñ class}') AS uf_acidente,
        l.uf_emp AS uf_empregador,
        l.municipio_codigo AS municipio_empregador_codigo,
        coalesce(mun.nome, nullif(split_part(trim(l.municipio_empregador),'-',2),'Ignorado')) AS municipio_empregador_nome,
        mun.uf_sigla AS municipio_uf,
        mun.regiao AS municipio_regiao,
        l.cbo_limpo AS cbo_codigo,
        coalesce(cbo.titulo, nullif(trim(l.cbo_descricao),'')) AS cbo_titulo,
        cbo.familia_titulo AS cbo_familia,
        nullif(l.cid_limpo, '') AS cid10_codigo,
        nullif(left(l.cid_limpo, 3), '') AS cid10_categoria,
        (sub.codigo IS NULL AND cat.codigo IS NOT NULL) AS cid10_so_categoria,
        coalesce(sub.descricao, cat.descricao, nullif(trim(l.cid10_descricao),'')) AS cid10_descricao,
        coalesce(sub.grupo_descricao, cat.grupo_descricao) AS cid10_grupo,
        coalesce(sub.capitulo_descricao, cat.capitulo_descricao) AS cid10_capitulo,
        l.cnae_limpo AS cnae_codigo,
        coalesce(cls.descricao, nullif(nullif(trim(l.cnae_descricao),'{ñ class}'),'')) AS cnae_descricao,
        cls.secao AS cnae_secao,
        l.tipo_limpo AS tipo_acidente,
        l.obito_limpo AS obito,
        l.sexo_limpo AS sexo,
        CASE WHEN l.geracao = 'B' THEN l.natureza_texto
             WHEN rn.prefixo IS NOT NULL THEN rn.rotulo_completo
             ELSE l.natureza_texto END AS natureza_lesao,
        coalesce(rn.familia, l.natureza_texto) AS natureza_lesao_familia,
        CASE WHEN l.geracao = 'B' THEN l.parte_texto
             WHEN rp.prefixo IS NOT NULL THEN rp.rotulo_completo
             ELSE l.parte_texto END AS parte_corpo,
        coalesce(rp.familia, l.parte_texto) AS parte_corpo_familia,
        CASE WHEN l.geracao = 'B' THEN l.agente_texto
             WHEN ra.prefixo IS NOT NULL THEN ra.rotulo_completo
             ELSE l.agente_texto END AS agente_causador,
        coalesce(ra.familia, l.agente_texto) AS agente_causador_familia,
        trim(l.origem_cadastramento) AS origem_cadastramento,
        trim(l.emitente_cat) AS emitente_cat,
        l.dt_nascimento AS data_nascimento,
        nullif(replace(replace(trim(l.cnpj_cei_empregador),'.',''),'/',''),'') AS cnpj_empregador,
        coalesce(l.dt_acidente >= cv3.inicio OR l.dt_acidente >= cv4.inicio, false) AS covid,
        ev.evento_id AS evento_catastrofico,
        l.emissao_copia_acidente,
        l.emissao_dia_unico,
        l.cid_corrompido,
        l.cid_ausente,
        -- identidade da CAT entre arquivos; o CID fica de fora porque e o campo
        -- que os arquivos sobrepostos corrompem ou truncam
        md5(concat_ws('|',
            coalesce(cast(l.dt_acidente AS string), '~'),
            coalesce(cast(l.dt_emissao_origem AS string), '~'),
            coalesce(cast(l.dt_nascimento AS string), '~'),
            coalesce(l.cbo_limpo, '~'),
            coalesce(l.cnae_limpo, '~'),
            coalesce(l.municipio_codigo, '~'),
            coalesce(l.sexo_limpo, '~'),
            coalesce(l.tipo_limpo, '~'),
            coalesce(cast(l.obito_limpo AS string), '~'),
            coalesce(l.uf_emp, '~'),
            coalesce(l.agente_prefixo, '~'),
            coalesce(l.parte_prefixo, '~'),
            coalesce(l.natureza_prefixo, '~'))) AS cat_chave
    FROM limpo l
    LEFT JOIN {{ source('bronze', 'cid10') }} sub
        ON sub.codigo = l.cid_limpo AND sub.nivel = 'subcategoria'
    LEFT JOIN {{ source('bronze', 'cid10') }} cat
        ON cat.codigo = left(l.cid_limpo, 3) AND cat.nivel = 'categoria'
    LEFT JOIN {{ source('bronze', 'cbo') }} cbo
        ON cbo.codigo = l.cbo_limpo AND cbo.nivel = 'ocupacao'
    LEFT JOIN {{ source('bronze', 'ibge_municipios') }} mun
        ON mun.codigo = split_part(trim(l.municipio_empregador),'-',1)
    LEFT JOIN {{ source('bronze', 'cnae_classes') }} cls
        ON cls.codigo = trim(l.cnae_codigo)
    LEFT JOIN {{ ref('cat_rotulo_familia') }} ra
        ON ra.campo = 'agente_causador' AND ra.prefixo = l.agente_prefixo
    LEFT JOIN {{ ref('cat_rotulo_familia') }} rp
        ON rp.campo = 'parte_corpo' AND rp.prefixo = l.parte_prefixo
    LEFT JOIN {{ ref('cat_rotulo_familia') }} rn
        ON rn.campo = 'natureza_lesao' AND rn.prefixo = l.natureza_prefixo
    -- U07 casa pelos tres primeiros caracteres, porque a partir de 202506 parte
    -- dos codigos chega truncada; B342 so conta a partir do inicio da pandemia
    LEFT JOIN {{ ref('cid_covid') }} cv3
        ON cv3.cid = left(l.cid_limpo, 3)
    LEFT JOIN {{ ref('cid_covid') }} cv4
        ON cv4.cid = left(l.cid_limpo, 4)
    LEFT JOIN {{ ref('eventos_catastroficos') }} ev
        ON ev.data_acidente = l.dt_acidente
       AND ev.uf_empregador = l.uf_emp
       AND (l.obito_limpo OR l.agente_texto LIKE ev.agente_padrao)
)
-- Alguns arquivos mensais sao cumulativos (202207 a 202210, 202404, 202506,
-- 202606) e repetem CAT publicadas nos meses seguintes. Fica a copia do arquivo
-- cujo mes e o da emissao e, no empate, a do arquivo mais recente. O dense_rank
-- remove so a repeticao entre arquivos: linhas iguais dentro do mesmo arquivo
-- permanecem, porque podem ser CAT distintas.
SELECT
    r.*,
    dense_rank() OVER (
        PARTITION BY r.cat_chave
        ORDER BY CASE WHEN date_format(r.data_emissao_cat_origem, '%Y%m') = r.periodo THEN 0 ELSE 1 END,
                 r.periodo DESC
    ) > 1 AS is_duplicata
FROM registros r
