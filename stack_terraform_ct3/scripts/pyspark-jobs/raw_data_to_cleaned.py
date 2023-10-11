# coding=utf-8

# Criado por: Juliana Soldera - Engenharia de Dados
# Popula as tabelas referentes aos dados do campeonato brasileiro

# LIBRARIES
import pyspark
from pyspark import SparkConf
from pyspark import SparkContext
from pyspark.sql import SQLContext, SparkSession, DataFrame
from pyspark.sql.functions import *
from pyspark.sql.types import *
from pyspark.sql.window import Window
from datetime import date, datetime, timedelta

# INPUT TABLES
INPUT_PATH_1 = 's3://bucket-raw-poc-juliana-4/campeonato_brasileiro_dataset-main/campeonato-brasileiro-cartoes.csv'
INPUT_PATH_2 = 's3://bucket-raw-poc-juliana-4/campeonato_brasileiro_dataset-main/campeonato-brasileiro-estatisticas-full.csv'
INPUT_PATH_3 = 's3://bucket-raw-poc-juliana-4/campeonato_brasileiro_dataset-main/campeonato-brasileiro-full.csv'
INPUT_PATH_4 = 's3://bucket-raw-poc-juliana-4/campeonato_brasileiro_dataset-main/campeonato-brasileiro-gols.csv'

# OUTPUT PATH
OUTPUT_PATH_1 = 's3://bucket-cleaned-poc-juliana-4/source=campeonato_brasileiro_dataset-main/campeonato-brasileiro-cartoes/'
OUTPUT_PATH_2 = 's3://bucket-cleaned-poc-juliana-4/source=campeonato_brasileiro_dataset-main/campeonato-brasileiro-estatisticas-full/'
OUTPUT_PATH_3 = 's3://bucket-cleaned-poc-juliana-4/source=campeonato_brasileiro_dataset-main/campeonato-brasileiro-full/'
OUTPUT_PATH_4 = 's3://bucket-cleaned-poc-juliana-4/source=campeonato_brasileiro_dataset-main/campeonato-brasileiro-gols/'

#========================================================================================================================

if __name__ == "__main__":

    sc = SparkContext()
    spark = SparkSession.builder.appName("App Process campeonato_brasileiro_dataset").enableHiveSupport().getOrCreate()

    df = spark.read.option("header", "true").csv(INPUT_PATH_1)
    df.repartition(1).write.parquet(path=OUTPUT_PATH_1, mode='overwrite')

    df = spark.read.option("header", "true").csv(INPUT_PATH_2)
    df.withColumn("chutes",df.chutes.cast('int'))
    df.withColumn("chutes_no_alvo",df.chutes_no_alvo.cast('int'))
    df.withColumn("passes",df.passes.cast('int'))
    df.withColumn("faltas",df.faltas.cast('int'))
    df.withColumn("cartao_amarelo",df.cartao_amarelo.cast('int'))
    df.withColumn("cartao_vermelho",df.cartao_vermelho.cast('int'))
    df.withColumn("impedimentos",df.impedimentos.cast('int'))
    df.withColumn("escanteios",df.escanteios.cast('int'))
    df.repartition(1).write.parquet(path=OUTPUT_PATH_2, mode='overwrite')

    df = spark.read.option("header", "true").csv(INPUT_PATH_3)
    df.withColumn("mandante_placar",df.mandante_placar.cast('int'))
    df.withColumn("visitante_placar",df.visitante_placar.cast('int'))
    df.repartition(1).write.parquet(path=OUTPUT_PATH_3, mode='overwrite')

    df = spark.read.option("header", "true").csv(INPUT_PATH_4)
    df.repartition(1).write.parquet(path=OUTPUT_PATH_4, mode='overwrite')

    sc.stop()