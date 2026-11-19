-- Concessoes acidentarias do INSS, uma linha por concessao.
--
-- O codigo da especie e a fonte de verdade quando existe (jun/2023 em
-- diante, com zero a esquerda no layout de out/2026); as regras por rotulo
-- valem so para os arquivos antigos, que nao trazem codigo. A ordem importa:
-- no layout de out/2026 o B91 se chama "Auxilio por Incapacidade Temporaria
-- Acidentaria", que o padrao generico de auxilio-acidente capturaria como 94.
SELECT
  periodo,
  CASE
    WHEN nullif(trim(especie_codigo),'') IS NOT NULL
      THEN CAST(CAST(trim(especie_codigo) AS INT) AS VARCHAR)
    WHEN lower(especie) LIKE '%previdenci%' THEN '36'
    WHEN lower(especie) LIKE '%doenc%acidente do trabalho%' THEN '91'
    WHEN lower(especie) LIKE '%invalidez%acident%' THEN '92'
    WHEN lower(especie) LIKE '%pens%morte%acident%' THEN '93'
    WHEN lower(especie) LIKE '%suplementar%acident%' THEN '95'
    WHEN lower(especie) LIKE '%aux%acident%' THEN '94'
  END AS especie_codigo,
  (lower(especie) NOT LIKE '%previdenci%') AS acidente_trabalho,
  trim(especie) AS especie,
  replace(nullif(trim(cid_codigo),''),'.','') AS cid10_codigo,
  trim(sexo) AS sexo,
  nullif(trim(uf),'') AS uf,
  trim(clientela) AS clientela,
  nullif(split_part(trim(municipio_residencia),'-',1),'') AS municipio_codigo,
  cast(replace(nullif(trim(qt_sm_rmi),''),',','.') AS DOUBLE) AS rmi_salarios_minimos,
  nullif(trim(ramo_atividade),'') AS ramo_atividade,
  nullif(trim(cnae_codigo),'0') AS cnae_codigo,
  arquivo_origem
FROM {{ source('bronze', 'inss_beneficios') }}
