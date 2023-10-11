# Import libraries
from datetime import timedelta, datetime
from airflow import DAG
from airflow.operators.dummy_operator import DummyOperator
from airflow.hooks.S3_hook import S3Hook
from airflow.operators.python import PythonOperator

from airflow.providers.amazon.aws.operators.emr import (
    EmrAddStepsOperator,
    EmrCreateJobFlowOperator,
    EmrTerminateJobFlowOperator,
)

from airflow.providers.amazon.aws.sensors.emr import EmrStepSensor



# Variables
BUCKET_NAME = 'bucket-jobs-poc-juliana-4' 
S3_SCRIPT = "process_data_from_campeonato_brasileiro/raw_data_to_cleaned.py"


# Spark Configurations
JOB_FLOW_OVERRIDES = {
    "Name": "Cluster da Juliana",
    "LogUri": "s3://bucket-logs-poc-juliana-4/",
    "ReleaseLabel": "emr-5.29.0",
    "Applications": [{"Name": "Hadoop"}, {"Name": "Spark"}],
    "Configurations": [
        {
            "Classification": "spark-env",
            "Configurations": [
                {
                    "Classification": "export",
                    "Properties": {"PYSPARK_PYTHON": "/usr/bin/python3"},
                }
            ],
        }
    ],
    "Instances": {
        "InstanceGroups": [
            {
                "Name": "Master node",
                "Market": "SPOT",
                "InstanceRole": "MASTER",
                "InstanceType": "m4.xlarge",
                "InstanceCount": 1,
            },
            {
                "Name": "Core - 2",
                "Market": "SPOT",
                "InstanceRole": "CORE",
                "InstanceType": "m4.xlarge",
                "InstanceCount": 2,
            },
        ],
        "KeepJobFlowAliveWhenNoSteps": True,
        "TerminationProtected": False,
    },
    "JobFlowRole": "EMR_EC2_DefaultRole",
    "ServiceRole": "EMR_DefaultRole",
}


# Steps to run
SPARK_STEPS = [
    {
        "Name": "Modeling data",
        "ActionOnFailure": "TERMINATE_CLUSTER",
        "HadoopJarStep": {"Jar": "command-runner.jar",
                            "Args": ["spark-submit",
                                    "--deploy-mode",
                                    "client",
                                    "s3://{{ params.BUCKET_NAME }}/{{ params.S3_SCRIPT }}",
                                    ],
                        },
    },
]


# Set default arguments
default_args = {
    "owner": "airflow",
    "start_date": datetime(2022, 3, 5),
    "email": ["airflow@airflow.com"],
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}

# DAG
with DAG(
    "process-campeonato-brasileiro-data",
    default_args=default_args,
    schedule_interval="0 1 * * *",
    max_active_runs=1,
    catchup=False
) as dag:

    # Only display - start_dag
    start_dag = DummyOperator(task_id="start_dag")

    # Create the EMR cluster
    create_emr_cluster = EmrCreateJobFlowOperator(
        task_id="create_emr_cluster",
        job_flow_overrides=JOB_FLOW_OVERRIDES,
        aws_conn_id="aws_default",
        emr_conn_id="emr_default",
    )

    # Add the steps to the EMR cluster
    add_steps = EmrAddStepsOperator(
        task_id="add_steps",
        job_flow_id="{{ task_instance.xcom_pull(task_ids='create_emr_cluster', key='return_value') }}",
        aws_conn_id="aws_default",
        steps=SPARK_STEPS,
        params={
            "BUCKET_NAME": BUCKET_NAME,
            "S3_SCRIPT": S3_SCRIPT,
        },
    )
    last_step = len(SPARK_STEPS) - 1

    # Wait executions of all steps
    check_execution_steps = EmrStepSensor(
        task_id="check_execution_steps",
        job_flow_id="{{ task_instance.xcom_pull('create_emr_cluster', key='return_value') }}",
        step_id="{{ task_instance.xcom_pull(task_ids='add_steps', key='return_value')["
        + str(last_step)
        + "] }}",
        aws_conn_id="aws_default",
    )

    # Terminate the EMR cluster
    terminate_emr_cluster = EmrTerminateJobFlowOperator(
        task_id="terminate_emr_cluster",
        job_flow_id="{{ task_instance.xcom_pull(task_ids='create_emr_cluster', key='return_value') }}",
        aws_conn_id="aws_default",
    )

    # Only display - end_dag
    end_dag = DummyOperator(task_id="end_dag")

    # Data pipeline flow
    start_dag >> create_emr_cluster >> add_steps
    add_steps >> check_execution_steps >> terminate_emr_cluster >> end_dag
    # add_steps >> check_execution_steps >> end_dag