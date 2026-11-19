-- Totais de cada edicao do Cadastro de Empregadores carregada.
--
-- A serie comeca na primeira edicao que o observatorio capturou; edicoes
-- anteriores so existem em PDFs que o ministerio substitui no mesmo
-- endereco, e por isso nao ha historico retroativo.
SELECT
    atualizado_em,
    COUNT(*) AS empregadores,
    SUM(trabalhadores) AS trabalhadores,
    SUM(CASE WHEN tipo_documento = 'CPF' THEN 1 ELSE 0 END) AS empregadores_pessoa_fisica,
    SUM(CASE WHEN inclusao_judicial THEN 1 ELSE 0 END) AS inclusoes_judiciais,
    COUNT(DISTINCT uf) AS ufs
FROM {{ source('bronze', 'mte_cadastro_empregadores') }}
GROUP BY atualizado_em
