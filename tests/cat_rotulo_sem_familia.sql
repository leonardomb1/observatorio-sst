{{ config(severity='warn') }}
-- Avisa quando aparece rotulo de agente, parte do corpo ou natureza da lesao
-- sem familia curada em seeds/cat_rotulo_familia.csv. O rotulo segue com o
-- texto da origem, mas pode ser o corte de 20 caracteres de um subtipo novo.
select 'agente_causador' as campo, agente_causador_familia as texto, count(*) as linhas
from {{ ref('silver__cat_registros') }} r
where agente_causador_familia is not null
  and not exists (select 1 from {{ ref('cat_rotulo_familia') }} f
                  where f.campo = 'agente_causador' and f.familia = r.agente_causador_familia)
group by 1, 2
union all
select 'parte_corpo', parte_corpo_familia, count(*)
from {{ ref('silver__cat_registros') }} r
where parte_corpo_familia is not null
  and not exists (select 1 from {{ ref('cat_rotulo_familia') }} f
                  where f.campo = 'parte_corpo' and f.familia = r.parte_corpo_familia)
group by 1, 2
union all
select 'natureza_lesao', natureza_lesao_familia, count(*)
from {{ ref('silver__cat_registros') }} r
where natureza_lesao_familia is not null
  and not exists (select 1 from {{ ref('cat_rotulo_familia') }} f
                  where f.campo = 'natureza_lesao' and f.familia = r.natureza_lesao_familia)
group by 1, 2
