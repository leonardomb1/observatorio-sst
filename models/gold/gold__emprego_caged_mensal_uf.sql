SELECT competencia, uf, SUM(admissoes) AS admissoes, SUM(desligamentos) AS desligamentos, SUM(saldo) AS saldo FROM {{ source('bronze', 'caged_saldo') }} GROUP BY competencia, uf
