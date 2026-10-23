-- Falha se algum arquivo da CAT tiver uma marca de defeito que nao esteja
-- documentada em seeds/cat_arquivos_conhecidos.csv. Defeito novo da origem
-- precisa ser visto e registrado antes de seguir para os paineis.
with marcas as (
    select periodo, 'emissao_copia_acidente' as defeito from {{ ref('silver__cat_registros') }} where emissao_copia_acidente group by periodo
    union all
    select periodo, 'emissao_dia_unico' from {{ ref('silver__cat_registros') }} where emissao_dia_unico group by periodo
    union all
    select periodo, 'cid_corrompido' from {{ ref('silver__cat_registros') }} where cid_corrompido group by periodo
    union all
    select periodo, 'cid_ausente' from {{ ref('silver__cat_registros') }} where cid_ausente group by periodo
)
select m.periodo, m.defeito
from marcas m
left join {{ ref('cat_arquivos_conhecidos') }} k
    on k.periodo = m.periodo and k.defeito = m.defeito
where k.periodo is null
