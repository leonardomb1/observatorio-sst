-- Pessoas envolvidas em acidentes nas rodovias federais (PRF).
--
-- A fonte nao marca acidente de trabalho; o que interessa ao observatorio e a
-- categoria do veiculo e o papel de quem estava nele, porque o condutor de
-- caminhao esta, por definicao, trabalhando. Semirreboque e reboque nao sao
-- veiculos conduzidos, aparecem sem papel e sem vitimas, e ficam na categoria
-- outros. As linhas sem papel definido (tipo_envolvido NA) sao veiculos sem
-- ocupante, todos com o mesmo identificador de pessoa, e saem do modelo.
SELECT
    ano,
    acidente_id,
    pessoa_id,
    str_to_date(data_inversa, '%Y-%m-%d') AS data_acidente,
    dia_semana,
    CAST(left(horario, 2) AS INT) AS hora,
    fase_dia,
    uf,
    br,
    causa_acidente,
    tipo_acidente,
    tipo_veiculo,
    CASE
        WHEN tipo_veiculo IN ('Caminhão', 'Caminhão-trator') THEN 'Caminhão'
        WHEN tipo_veiculo IN ('Ônibus', 'Micro-ônibus') THEN 'Ônibus'
        WHEN tipo_veiculo IN ('Motocicleta', 'Motoneta', 'Ciclomotor') THEN 'Motocicleta'
        WHEN tipo_veiculo IN ('Automóvel', 'Caminhonete', 'Camioneta', 'Utilitário') THEN 'Automóvel e utilitário'
        WHEN tipo_veiculo = 'Bicicleta' THEN 'Bicicleta'
        ELSE 'Outros'
    END AS categoria_veiculo,
    tipo_envolvido,
    tipo_envolvido = 'Condutor' AS condutor,
    estado_fisico,
    estado_fisico = 'Óbito' AS obito,
    estado_fisico = 'Lesões Graves' AS ferido_grave,
    CASE WHEN idade REGEXP '^[0-9]+$' AND CAST(idade AS INT) BETWEEN 1 AND 99
         THEN CAST(idade AS INT) END AS idade,
    nullif(nullif(sexo, 'NA'), 'Não Informado') AS sexo
FROM {{ source('bronze', 'prf_envolvidos') }}
WHERE tipo_envolvido <> 'NA'
