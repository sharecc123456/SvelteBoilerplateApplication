#!/usr/bin/env python
# Copyright 2020 (c) Boilerplate, Inc.
# Author: Levente Kurusa <lev@boilerplate.co>
#
# Puts an IACMask on a PDF document to visualize the mask
# This tool is mostly for debugging IACMasks and their caches.
from reportlab import pdfgen
from reportlab.pdfgen.canvas import Canvas
from pdfrw import PdfReader
from pdfrw.buildxobj import pagexobj
from pdfrw.toreportlab import makerl
import sys
import json

mask_filename = sys.argv[1]
pdf_filename = sys.argv[2]
target_filename = sys.argv[3]

mask_fd = open(mask_filename, "r")
mask_obj = json.load(mask_fd)

pages = PdfReader(pdf_filename).pages
pages = [pagexobj(x) for x in pages]
main_page = pages[0]

canvas = Canvas(target_filename)
x_max = max(page.BBox[2] for page in pages)
y_max = max(page.BBox[3] for page in pages)
canvas.setPageSize((x_max, y_max))
canvas.doForm(makerl(canvas, main_page))
canvas.setStrokeColorRGB(0.2,0.5,0.3)
canvas.setFillColorRGB(1,0,1)

for field in mask_obj["fields"]:
    lv1 = float(field["location_value_1"])
    lv2 = float(field["location_value_2"])
    lv3 = float(field["location_value_3"])
    lv4 = float(field["location_value_4"])
    top = 1 - lv1
    left = lv2
    width = lv3
    height = lv4

    canvas.rect(left * x_max, (top - height) * y_max, width * x_max, height * y_max)

canvas.showPage()
canvas.save()
