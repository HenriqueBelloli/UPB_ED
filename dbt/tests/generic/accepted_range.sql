{% test accepted_range(model, column_name, min_value, inclusive=true) %}

SELECT *
FROM {{ model }}
WHERE {{ column_name }} IS NULL
{% if inclusive %}
   OR {{ column_name }} < {{ min_value }}
{% else %}
   OR {{ column_name }} <= {{ min_value }}
{% endif %}

{% endtest %}
