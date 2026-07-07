{% macro create_probit_udf() %}

{% set python_version_query %}
    SELECT DISTINCT
        runtime_version
    FROM SNOWFLAKE.INFORMATION_SCHEMA.PACKAGES
    WHERE language = 'python'
        and package_name = 'scipy'
        and runtime_version IS NOT NULL
    order by to_number(SPLIT_PART(runtime_version,'.',1)) desc ,to_number(SPLIT_PART(runtime_version,'.',2)) desc
    limit 1;
{% endset %}

{% set results = run_query(python_version_query) %}
{% set python_version = results.columns[0].values()[0] %}
{% set create_udf %}

CREATE OR REPLACE FUNCTION AGOS_DEV_16000.L0.PROBIT(p DOUBLE)
RETURNS DOUBLE
LANGUAGE PYTHON
RUNTIME_VERSION = '{{ python_version }}'
PACKAGES = ('scipy')
HANDLER = 'probit'
AS
$$
from scipy.stats import norm
def probit(p):
    return norm.ppf(p)
$$;

{% endset %}

{% do run_query(create_udf) %}

{% endmacro %}