from datetime import datetime
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.models import Variable

# DAG to run dbt deps/run/test inside Composer environment

default_args = {
    "owner": "data-platform",
    "depends_on_past": False,
}

with DAG(
    dag_id="dbt_orchestration",
    default_args=default_args,
    start_date=datetime(2024, 1, 1),
    schedule_interval="0 */6 * * *",
    catchup=False,
    max_active_runs=1,
    tags=["dbt", "bigquery"],
):
    env = Variable.get("ENV", default_var="dev")
    dbt_dir = "/home/airflow/gcs/data/dbt"  # sync your dbt project here via CI

    dbt_deps = BashOperator(
        task_id="dbt_deps",
        bash_command=f"cd {dbt_dir} && dbt deps --no-write-json",
        env={"DBT_TARGET": env},
    )

    dbt_run = BashOperator(
        task_id="dbt_run",
        bash_command=f"cd {dbt_dir} && dbt run --target {env} --fail-fast",
    )

    dbt_test = BashOperator(
        task_id="dbt_test",
        bash_command=f"cd {dbt_dir} && dbt test --target {env}",
    )

    dbt_deps >> dbt_run >> dbt_test
