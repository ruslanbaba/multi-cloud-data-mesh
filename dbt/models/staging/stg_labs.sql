{% set env = var('env', target.name) %}
{% set dataset = domain_dataset('labs', env) %}

with src as (
  select * from `{{ env_var('GCP_PROJECT_ID') }}`.{{ dataset }}.labs_external
)
select
  cast(patient_id as string) as patient_id,
  cast(loinc_code as string) as loinc_code,
  timestamp(result_datetime) as result_ts
from src
