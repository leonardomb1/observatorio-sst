-- Falha se algum mes de beneficios por incapacidade tiver menos da metade da
-- mediana dos meses, fora as quedas ja conhecidas: dez/2018 e o primeiro mes
-- da serie, abr/2020 e o fechamento das agencias na pandemia, abr/2022 e
-- set/2026 sao meses que a fonte publicou com volume muito abaixo do normal.
-- A fonte ja mudou de layout sem aviso (out/2026); um mes truncado ou mal
-- mapeado passaria sem erro numa serie agregada.
with mensal as (
    select periodo, sum(concessoes) as concessoes
    from {{ ref('silver__inss_incapacidade') }}
    group by periodo
),
referencia as (
    select percentile_approx(concessoes, 0.5) as mediana from mensal
)
select m.periodo, m.concessoes, r.mediana
from mensal m cross join referencia r
where m.concessoes < r.mediana * 0.5
  and m.periodo not in ('201812', '202004', '202204', '202609')
