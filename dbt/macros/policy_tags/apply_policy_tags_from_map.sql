{% macro apply_policy_tags_from_map(mapping_file='dbt/policy_tags_map.yml') %}
{#- Load YAML mapping and emit ALTER COLUMN statements (idempotent) -#}
{% set mapping = fromyaml(load_file(mapping_file)) %}
{% for model_name, colmap in mapping.get('models', {}).items() %}
  {% set rel = ref(model_name) %}
  {% set dataset = rel.schema %}
  {% set table = rel.identifier %}
  {% for col, tag in colmap.items() %}
    {% set resolved_tag = (env_var(tag.strip('${'))) if tag is string and tag.startswith('${') else tag %}
    {% if resolved_tag is string and resolved_tag|length > 0 %}
    alter table `{{ rel.database }}`.{{ dataset }}.{{ table }}
    alter column {{ col }} set policy tags ("{{ resolved_tag }}");
    {% endif %}
  {% endfor %}
{% endfor %}
{% endmacro %}
