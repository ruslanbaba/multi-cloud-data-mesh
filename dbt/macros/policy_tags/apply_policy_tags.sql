{% macro apply_policy_tags(dataset, table, column_tags) %}
-- column_tags is a dict: { column_name: policy_tag_id }
{% for col, tag in column_tags.items() %}
  alter table `{{ env_var('GCP_PROJECT_ID') }}`.{{ dataset }}.{{ table }}
  alter column {{ col }} set policy tags ("{{ tag }}");
{% endfor %}
{% endmacro %}
