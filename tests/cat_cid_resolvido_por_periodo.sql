-- Falha se algum arquivo da CAT, fora dos marcados sem CID, resolver menos de
-- 90% dos codigos informados para um capitulo da CID-10. O teste global que
-- existia antes media a serie inteira e nao enxergava um arquivo isolado com
-- codigos corrompidos, como o de 202507.
select periodo, count(*) as com_cid,
       sum(case when cid10_capitulo is not null then 1 else 0 end) as resolvidos
from {{ ref('silver__cat_registros') }}
where cid10_codigo is not null
  and not cid_ausente
group by periodo
having sum(case when cid10_capitulo is not null then 1 else 0 end) < count(*) * 0.90
