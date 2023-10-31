#!/usr/bin/env python3
# Copyright 2020-2022 (c) Boilerplate, Inc.
# Author: Levente Kurusa <lev@boilerplate.co>
#
# Try to parse PDFs to gather some form information
from pdfrw import PdfReader
import sys
import json
import tempfile
import subprocess

def deep_find_parenttype(orig_type, field_name, field, page_no):
    if field.Type != None:
        #  print("%s (%s) @ %s" % (field.Type, field.T, field.Rect))
        all_fields.append({"name": field_name, "type": orig_type, "rect": field.Rect, "page": page_no})
    else:
        for kid in field.Kids:
            deep_find_parenttype(orig_type, field_name, kid, page_no)

def deep_find_type(field, page_no):
    if field.FT != None:
        rect = field.inheritable.Rect
        if field.T is None:
            field_name = "Un-named, auto-detected field"
        else:
            field_name = field.T
        if rect != None:
            #  print("%s (%s) @ %s" % (field.FT, field.T, field.inheritable.Rect))
            all_fields.append({"name": field_name, "type": field.FT, "rect": field.inheritable.Rect, "page": page_no})
        else:
            #print("%s @ None but parent type: " % field.FT)
            deep_find_parenttype(field.FT, field_name, field, page_no)
    else:
        for kids in field.Kids:
            deep_find_type(kids, page_no)

def find_page_no(field):
    if (field.P is None):
        # recurse into Kids
        retvals = []
        if not (field.Kids is None):
            for kid in field.Kids:
                retvals.append(find_page_no(kid))

        retvals = list(filter(lambda x: x != -1, retvals))
        if len(retvals) == 0:
            return -1
        else:
            return retvals[0]
    else:
        for i in range(len(reader.pages)):
            if (reader.pages[i] == field.P):
                return i

        return -1

def fieldify(f):
    rect = f["rect"]
    page_no = f["page"]
    geom = (float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))
    return (f["type"], geom, f["name"], page_no)

acro_fields = []
final_state = 0

json_filename = sys.argv[2]
json_fd = open(json_filename, "w")

all_fields = []

try:
    filename = sys.argv[1]
    # Before processing the PDF generate a temporary file
    temp = tempfile.NamedTemporaryFile(prefix="boilerplate-iac-")
    subprocess.run(["pdftk", filename, "output", temp.name, "uncompress"])
    reader = PdfReader(temp.name)

    page_obj = reader.pages[0]
    media_box = page_obj['/MediaBox']

    acro = reader.Root.AcroForm
    all_terminal_fields = []
    for a in acro.Fields:
        ak = a.Kids
        if not (ak is None):
            for b in ak:
                fields = b.Kids
                if not (fields is None):
                    for field in fields:
                        deep_find_type(field, find_page_no(field))
        if not (a.FT is None):
            deep_find_type(a, find_page_no(a))

    final_list = set()
    for i in all_fields:
        ff = fieldify(i)
        if ff not in final_list:
            final_list.add(ff)

    for i in final_list:
        rect = i[1]
        type = i[0]
        name = i[2]
        pageno = i[3]
        top = 1 - (float(rect[3]) / float(media_box[3]))
        left = (float(rect[0]) / float(media_box[2]))
        width = (float(rect[2]) - float(rect[0])) / float(media_box[2])
        height = (float(rect[3]) - float(rect[1])) / float(media_box[3])
        ft = 1

        name = "future_fix"

        if type == "/Tx":
            ft = 1
        elif type == "/Btn":
            ft = 2
        elif type == "/Sig":
            ft = 3

        #print("%s @ %s" % (ft, rect))
        acro_fields.append({
            "default_value": "",
            "field_type": ft,
            "internal_value_1": "",
            "location_type": 1,
            "location_value_1": top,
            "location_value_2": left,
            "location_value_3": width,
            "location_value_4": height,
            "location_value_5": 0,
            "location_value_6": pageno,
            "name": name,
        })
except:
    final_state = 1

iac_mask = {
    "boilerplate_version": "boilerplate-42",
    "iac_version": "1",
    "mask_creator": "acroform_to_mask",
    "document_hash_signature": "0",
    "state": final_state,
    "fields": acro_fields,
}

output_str = json.dumps(iac_mask)
json_fd.write(output_str)
json_fd.write("\n")
#close(json_fd)
