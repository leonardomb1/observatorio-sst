SELECT ref_area AS pais_iso3, ano, valor AS taxa_fatal_100k, fonte FROM {{ source('bronze', 'ilo_sst_taxas') }} WHERE indicador='SDG_F881' AND sexo='SEX_T' AND mig='MIG_STATUS_TOTAL'
