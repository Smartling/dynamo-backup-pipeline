from __future__ import print_function

import json
import boto3
import uuid

pipeline_client = boto3.client('datapipeline')
dynamodb_client = boto3.resource('dynamodb')


def lambda_handler(event, context):
    try:
        print(event)

        message = json.loads(event['Records'][0]['Sns']['Message'])
        print("received sns", message)

        assert message['State'] == 'Succeeded'
        s3folder = message['S3FolderForBackup']
        print("s3 folder to get backups from:" + s3folder)
        dynamo_table_name = message['DynamoDBTableName']
        print("dynamo table name:" + dynamo_table_name)
        clone_dynamo_table_name = dynamo_table_name + "-backup_verification_temp_table-" + str(uuid.uuid4())

        pipeline_id = get_pipeline_id_by_name(dynamo_table_name + "-dynamo-restore-pipeline")
        print("found pipeline id:" + pipeline_id)

        clone_dynamo_table(dynamo_table_name, clone_dynamo_table_name)
        response = pipeline_client.activate_pipeline(
            pipelineId=pipeline_id,
            parameterValues=[
                {
                    'id': 'my_source_s3_folder',
                    'stringValue': s3folder
                },
                {
                    'id': 'my_destination_dynamo_table',
                    'stringValue': clone_dynamo_table_name
                }
            ]
        )
        print("pipeline started")
        return response
    except Exception as e:
        print(e)
        raise e


def get_pipeline_id_by_name(name):
    pipelines = pipeline_client.list_pipelines()
    for x in pipelines['pipelineIdList']:
        print(x)
        if x['name'] == name:
            return x['id']


def get_key_definition(key_schema, attribute_name):
    print("looking for attribute in schema:", attribute_name)
    for x in key_schema:
        print(x)
        if x['AttributeName'] == attribute_name:
            return x
    print("not found", attribute_name)


def clone_dynamo_table(src_table_name, dst_table_name):
    print("Creating temp dynamoDB table")
    src_table = dynamodb_client.Table(src_table_name)

    del src_table.provisioned_throughput["NumberOfDecreasesToday"]
    del src_table.provisioned_throughput["LastIncreaseDateTime"]

    print("Schema:", src_table.key_schema)
    print("Attribute definitions:", src_table.attribute_definitions)
    print("Provisioned throughput:", src_table.provisioned_throughput)

    key_name_1 = src_table.key_schema[0]['AttributeName']
    key_name_2 = src_table.key_schema[1]['AttributeName']
    key_definition_1 = get_key_definition(src_table.attribute_definitions, key_name_1)
    key_definition_2 = get_key_definition(src_table.attribute_definitions, key_name_2)
    print(key_definition_1)
    print(key_definition_2)

    dst_table = dynamodb_client.create_table(
        TableName=dst_table_name,
        KeySchema=src_table.key_schema,
        AttributeDefinitions=[key_definition_1, key_definition_2],
        ProvisionedThroughput=src_table.provisioned_throughput
    )

    # Wait until the table exists.
    dst_table.meta.client.get_waiter('table_exists').wait(TableName=src_table_name)
