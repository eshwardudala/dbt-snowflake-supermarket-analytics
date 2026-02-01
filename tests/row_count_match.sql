select 1
where
    (select count(*) from {{ ref('stg_source') }})
    !=
    (select count(*) from {{ ref('stg_target') }})