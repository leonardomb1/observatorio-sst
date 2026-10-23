-- Acidentes por municipio do empregador. As colunas sem_* aplicam ao
-- numerador o mesmo corte de divisoes CNAE do denominador; a CAT sem CNAE
-- informado fica no numerador, porque sua divisao e desconhecida.
SELECT
    ano,
    municipio_empregador_codigo AS municipio_codigo,
    max(municipio_empregador_nome) AS municipio,
    max(municipio_uf) AS uf,
    max(municipio_regiao) AS regiao,
    COUNT(*) AS acidentes,
    SUM(obito) AS obitos,
    SUM(CASE WHEN {{ na_lista_de_divisoes("left(lpad(cnae_codigo, 4, '0'), 2)", var('divisoes_adm_publica')) }}
             THEN 0 ELSE 1 END) AS acidentes_sem_adm_publica,
    SUM(CASE WHEN {{ na_lista_de_divisoes("left(lpad(cnae_codigo, 4, '0'), 2)", var('divisoes_adm_publica')) }}
             THEN 0 WHEN obito THEN 1 ELSE 0 END) AS obitos_sem_adm_publica,
    SUM(CASE WHEN {{ na_lista_de_divisoes("left(lpad(cnae_codigo, 4, '0'), 2)", var('divisoes_84_88')) }}
             THEN 0 ELSE 1 END) AS acidentes_sem_divisoes_84_88,
    SUM(CASE WHEN {{ na_lista_de_divisoes("left(lpad(cnae_codigo, 4, '0'), 2)", var('divisoes_84_88')) }}
             THEN 0 WHEN obito THEN 1 ELSE 0 END) AS obitos_sem_divisoes_84_88,
    SUM(CASE WHEN cnae_codigo IS NULL THEN 1 ELSE 0 END) AS acidentes_sem_cnae,
    SUM(CASE WHEN evento_catastrofico IS NOT NULL THEN 1 ELSE 0 END) AS acidentes_evento,
    SUM(CASE WHEN evento_catastrofico IS NOT NULL AND obito THEN 1 ELSE 0 END) AS obitos_evento,
    SUM(CASE WHEN covid THEN 1 ELSE 0 END) AS acidentes_covid,
    SUM(CASE WHEN covid AND obito THEN 1 ELSE 0 END) AS obitos_covid
FROM {{ ref('silver__acidentes') }}
WHERE ano IS NOT NULL AND municipio_empregador_nome IS NOT NULL
GROUP BY 1, 2
