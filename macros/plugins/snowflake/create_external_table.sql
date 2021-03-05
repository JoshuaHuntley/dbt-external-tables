{% macro snowflake__create_external_table(source_node) %}

    {%- set columns = source_node.columns.values() -%}
    {%- set external = source_node.external -%}
    {%- set partitions = external.partitions -%}

    {%- set is_csv = dbt_external_tables.is_csv(external.file_format) -%}

{# https://docs.snowflake.net/manuals/sql-reference/sql/create-external-table.html #}
{# This assumes you have already created an external stage #}
    create or replace external table {{source(source_node.source_name, source_node.name)}}
    {%- if columns or partitions -%}
    (
        {%- if partitions -%}{%- for partition in partitions %}
            {{partition.name}} {{partition.data_type}} as {{partition.expression}}{{- ',' if not loop.last or columns|length > 0 -}}
        {%- endfor -%}{%- endif -%}
        {%- for column in columns %}
            {%- set col_name -%}
                {%- if is_csv and column.name == 'METADATA$FILENAME' -%}METADATA_FILENAME
                {%- else -%}{{column.name}}
                {%- endif -%}
            {%- endset %}
            {%- set column_quoted = adapter.quote(col_name) if column.quote else col_name %}
            {%- set col_expression -%}
                {%- if is_csv and col_name == 'METADATA_FILENAME' -%}{{column.name}}{# special case: add support to append external source file name. This must be the last column or it will break the ingest #}
                {%- elif is_csv -%}nullif(value:c{{loop.index}},''){# special case: get columns by ordinal position #}
                {%- else -%}nullif(value:{{col_name}},''){# standard behavior: get columns by name #}
                {%- endif -%}
            {%- endset %}
            {{column_quoted}} {{column.data_type}} as ({{col_expression}}::{{column.data_type}})
            {{- ',' if not loop.last -}}
        {% endfor %}
    )
    {%- endif -%}
    {% if partitions %} partition by ({{partitions|map(attribute='name')|join(', ')}}) {% endif %}
    location = {{external.location}} {# stage #}
    {% if external.auto_refresh -%} auto_refresh = {{external.auto_refresh}} {%- endif %}
    {% if external.pattern -%} pattern = '{{external.pattern}}' {%- endif %}
    file_format = {{external.file_format}}
{% endmacro %}
