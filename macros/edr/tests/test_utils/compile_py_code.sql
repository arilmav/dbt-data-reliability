{% macro snowflake__compile_py_code(model, py_code, output_table) %}
import pandas
import snowflake.snowpark

{{ py_code }}

def materialize(session, test_passed, target_relation):
    df = session.create_dataframe([[test_passed]], ['test_passed'])
    df.write.mode('overwrite').save_as_table(target_relation, table_type='temporary')

def did_pass(test_output):
    if isinstance(test_output, bool):
        return test_output
    if isinstance(test_output, snowflake.snowpark.DataFrame):
        return test_output.count() == 0
    if isinstance(test_output, pandas.DataFrame):
        return test_output.empty
    raise ValueError('Received invalid return value, expected either DataFrame or a boolean.')

def main(session):
    ref = session.table
    model_df = ref('{{ model }}')
    test_output = test(model_df, ref, session)
    materialize(session, did_pass(test_output), '{{ output_table }}')
{% endmacro %}


{% macro bigquery__compile_py_code(model, py_code, output_table) %}
import pandas
import pyspark.sql

{{ py_code }}

def materialize(session, test_passed, target_relation):
    df = session.createDataFrame([[test_passed]], ['test_passed'])
    df.write.mode('overwrite').format('bigquery').option('writeMethod', 'direct').option('writeDisposition', 'WRITE_TRUNCATE').save(target_relation)

def did_pass(test_output):
    if isinstance(test_output, bool):
        return test_output
    if isinstance(test_output, pyspark.sql.DataFrame):
        return test_output.count() == 0
    if isinstance(test_output, pandas.DataFrame):
        return test_output.empty
    raise ValueError('Received invalid return value, expected either DataFrame or a boolean.')

def get_session():
    session = pyspark.sql.SparkSession.builder.appName('Elementary').getOrCreate()
    session.conf.set('viewsEnabled', 'true')
    session.conf.set('temporaryGcsBucket', '{{ target.gcs_bucket }}')
    return session

def main():
    session = get_session()
    ref = session.read.format('bigquery').load
    model_df = ref('{{ model }}')
    test_output = test(model_df, ref, session)
    materialize(session, did_pass(test_output), '{{ output_table }}')

main()
{% endmacro %}
