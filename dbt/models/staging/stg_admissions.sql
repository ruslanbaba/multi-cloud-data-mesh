{% set env = var('env', target.name) %}
{% set dataset = domain_dataset('admissions', env) %}

with src as (
  select * from `{{ env_var('GCP_PROJECT_ID') }}`.{{ dataset }}.admissions_external
)
select
  cast(patient_id as string) as patient_id,
  timestamp(admission_datetime) as admission_ts,
  cast(hospital_id as string) as hospital_id
from src
