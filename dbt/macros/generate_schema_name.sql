-- Use the schema names exactly as written in dbt_project.yml
-- (staging, dw) instead of dbt's default "main_staging", "main_dw".
{% macro generate_schema_name(custom_schema_name, node) -%}
    {{ custom_schema_name | trim if custom_schema_name else target.schema }}
{%- endmacro %}
