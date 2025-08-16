with admissions as (
  select patient_id, min(admission_ts) as first_admission
  from {{ ref('stg_admissions') }}
  group by 1
)
select * from admissions
