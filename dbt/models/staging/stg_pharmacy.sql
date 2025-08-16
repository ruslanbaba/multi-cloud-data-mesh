{% set env = var('env', target.name) %}
{% set dataset = domain_dataset('pharmacy', env) %}

with src as (
  select * from `{{ env_var('GCP_PROJECT_ID') }}`.{{ dataset }}.pharmacy_external
)
select
  cast(patient_id as string) as patient_id,
  cast(ndc_code as string) as ndc_code,
  cast(status as string) as status,
  timestamp(dispense_datetime) as dispense_ts
from src
