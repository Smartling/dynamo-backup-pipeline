from __future__ import print_function

import json
import boto3

dynamodb_client = boto3.resource('dynamodb')
dynamodb_streams = boto3.client('dynamodb')


def get_attribute_name(key_schema, key_type):
    for x in key_schema:
        if x['KeyType'] == key_type:
            return x['AttributeName']


def lambda_handler(event, context):
    restored_table_name = ""
    try:
        print(event)

        message = json.loads(event['Records'][0]['Sns']['Message'])
        print("received sns", message)

        assert message['State'] == 'Succeeded'
        original_table_name = message['OriginalTableName']
        print("original_table_name:" + original_table_name)
        restored_table_name = message['RestoredTableName']
        print("restored_table_name:" + restored_table_name)

        restored_table = dynamodb_client.Table(restored_table_name)
        hash_name = get_attribute_name(restored_table.key_schema, 'HASH')
        range_name = get_attribute_name(restored_table.key_schema, 'RANGE')
        print("hash_name:{} range_name:{}".format(hash_name, range_name))

        print("Scanning tables")
        original_table_iterator = get_scan_iterator(original_table_name, hash_name, range_name)
        mismatch_count = 0
        total_count = 0
        for item_list in original_table_iterator:
            for item in item_list['Items']:
                total_count += 1
                if not is_item_exists(restored_table, item):
                    mismatch_count += 1

        if mismatch_count != 0:
            message = 'tables {} and {} have {} ouf of {} mismatched records'. \
                format(original_table_name, restored_table_name, mismatch_count, total_count)
            raise Exception(message)

        return "Success"
    except Exception as e:
        print(e)
        raise e
    finally:
        print("Deleting temp table:", restored_table_name)
        if restored_table_name != "":
            dynamodb_streams.delete_table(
                TableName=restored_table_name
            )


def get_scan_iterator(table_name, hash_name, range_name):
    src_paginator = dynamodb_streams.get_paginator('scan').paginate(
        TableName=table_name,
        AttributesToGet=[
            hash_name, range_name
        ],
        Select='SPECIFIC_ATTRIBUTES',
        ReturnConsumedCapacity='TOTAL',
        PaginationConfig={
            'MaxItems': 10,
            'PageSize': 1
        }
    )
    return src_paginator


# item_to_get format {u'id': {u'S': u'2'}}
def is_item_exists(table, item_to_get):
    print("getting item:", item_to_get)

    response = table.get_item(
        Key={
            item_to_get.keys()[0]: item_to_get.values()[0].values()[0],
            item_to_get.keys()[1]: item_to_get.values()[1].values()[0]
        },
        AttributesToGet=[
            'id'
        ],
        ConsistentRead=False
    )
    print(response)
    if 'Item' in response:
        return True
    print("not found  {} in restored table".format(item_to_get))
    return False
