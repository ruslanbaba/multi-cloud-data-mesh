{% set env = var('env', target.name) %}
{% set dataset = 'marts' %}

-- Example: apply a PHI policy tag to patient_id in patient_360
{% do apply_policy_tags(dataset, 'patient_360', {
  'patient_id': env_var('PHI_POLICY_TAG_ID', '')
}) %}

select * from {{ ref('patient_360') }}
