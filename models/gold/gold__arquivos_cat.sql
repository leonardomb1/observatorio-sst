-- Uma linha por arquivo mensal da CAT carregado no bronze, com o volume, a
-- faixa de emissao e as marcas de defeito medidas no silver. Serve para
-- mostrar ao leitor de onde vem cada mes da serie e o que se sabe da fonte.
WITH conhecidos AS (
    SELECT periodo,
           group_concat(defeito ORDER BY defeito SEPARATOR ', ') AS defeito_conhecido,
           group_concat(nota ORDER BY defeito SEPARATOR ' | ') AS nota
    FROM {{ ref('cat_arquivos_conhecidos') }}
    GROUP BY periodo
)
SELECT
    r.periodo,
    max(r.arquivo_origem) AS arquivo_origem,
    max(r.geracao) AS geracao,
    COUNT(*) AS linhas,
    SUM(CASE WHEN r.is_duplicata THEN 0 ELSE 1 END) AS linhas_mantidas,
    min(r.data_emissao_cat_origem) AS emissao_min,
    max(r.data_emissao_cat_origem) AS emissao_max,
    max(r.emissao_copia_acidente) AS emissao_copia_acidente,
    max(r.emissao_dia_unico) AS emissao_dia_unico,
    max(r.cid_corrompido) AS cid_corrompido,
    max(r.cid_ausente) AS cid_ausente,
    max(k.defeito_conhecido) AS defeito_conhecido,
    max(k.nota) AS nota
FROM {{ ref('silver__cat_registros') }} r
LEFT JOIN conhecidos k ON k.periodo = r.periodo
GROUP BY r.periodo
