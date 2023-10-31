import json
import sys

json_file = sys.argv[1]
data = json.load(open(json_file))
blocks=data["Blocks"]

def find_value_block(key_block, value_map):
    for relationship in key_block['Relationships']:
        if relationship['Type'] == 'VALUE':
            for value_id in relationship['Ids']:
                value_block = value_map[value_id]
    return value_block

def get_text(result, blocks_map):
    text = ''
    if 'Relationships' in result:
        for relationship in result['Relationships']:
            if relationship['Type'] == 'CHILD':
                for child_id in relationship['Ids']:
                    word = blocks_map[child_id]
                    if word['BlockType'] == 'WORD':
                        text += word['Text'] + ' '
                    if word['BlockType'] == 'SELECTION_ELEMENT':
                        if word['SelectionStatus'] == 'SELECTED':
                            text += 'X '    
                        else:
                            text += 'O '
    return text

# get key and value maps
key_map = {}
value_map = {}
block_map = {}
id_ordering = []
for block in blocks:
    block_id = block['Id']
    block_map[block_id] = block
    if block['BlockType'] == "KEY_VALUE_SET":
        if 'KEY' in block['EntityTypes']:
            key_map[block_id] = block
            id_ordering.append(block_id)
        else:
            value_map[block_id] = block

# Sort by top-to-bottom
id_ordering.sort(key=lambda block:
        [key_map[block]['Geometry']['BoundingBox']['Top'], key_map[block]['Geometry']['BoundingBox']['Left']])

for block_id in id_ordering:
    key_block = key_map[block_id]
    value_block = find_value_block(key_block, value_map)
    top = value_block["Geometry"]["BoundingBox"]["Top"];
    left = value_block["Geometry"]["BoundingBox"]["Left"];
    width = value_block["Geometry"]["BoundingBox"]["Width"];
    height = value_block["Geometry"]["BoundingBox"]["Height"];
    key = get_text(key_block, block_map)
    val = get_text(value_block, block_map)
    print(key, ": \"", val, "\" (located at TOP ", top, " LEFT ", left, " WIDTH ", width, " HEIGHT ", height, ")")
