{% set env = var('env', target.name) %}
{% set dataset = domain_dataset('radiology', env) %}

with src as (
  select * from `{{ env_var('GCP_PROJECT_ID') }}`.{{ dataset }}.radiology_external
)
select
  cast(patient_id as string) as patient_id,
  cast(modality as string) as modality,
  timestamp(study_datetime) as study_ts
from src
