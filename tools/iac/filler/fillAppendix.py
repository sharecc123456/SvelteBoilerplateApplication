#!/usr/bin/env python3
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, inch, landscape
from reportlab.platypus import (
    SimpleDocTemplate,
    Table,
    Spacer,
    TableStyle,
    Paragraph,
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
import json
import sys

blpt_data = {}
with open(sys.argv[1], "r") as f:
    blpt_data = json.load(f)

target_file = sys.argv[2]

doc = SimpleDocTemplate(
    target_file,
    pagesize=A4,
    rightMargin=30,
    leftMargin=30,
    topMargin=30,
    bottomMargin=18,
)
doc.pagesize = landscape(A4)
elements = []

data = [blpt_data["form_headers"]]
for j in blpt_data["form_values"]:
    d = []
    for i in j:
        if isinstance(i, list):
            x = list(map(lambda x: str(x), i))
            y = ", ".join(x)
            d.append(y)
        else:
            d.append(i)
    data.append(d)

print(data)

# TODO: Get this line right instead of just copying it from the docs
style = TableStyle(
    [
        ("ALIGN", (1, 1), (-2, -2), "RIGHT"),
        ("TEXTCOLOR", (1, 1), (-2, -2), colors.red),
        # ("VALIGN", (0, 0), (0, -1), "TOP"),
        ("TEXTCOLOR", (0, 0), (0, -1), colors.blue),
        ("ALIGN", (0, -1), (-1, -1), "CENTER"),
        # ("VALIGN", (0, -1), (-1, -1), "MIDDLE"),
        ("TEXTCOLOR", (0, -1), (-1, -1), colors.green),
        ("INNERGRID", (0, 0), (-1, -1), 0.25, colors.black),
        ("BOX", (0, 0), (-1, -1), 0.25, colors.black),
    ]
)

# Configure style and word wrap
styles = getSampleStyleSheet()
s = styles["BodyText"]
s.wordWrap = "CJK"
data2 = [[Paragraph(cell, s) for cell in row] for row in data]
t = Table(data2)
t.setStyle(style)

# Styles
# styles.add(ParagraphStyle(name="Title", fontSize=32))

# Header
title = Paragraph(blpt_data["checklist_title"], styles["Heading1"])
recipient = Paragraph(blpt_data["recipient_name"], styles["Normal"])
prepare_line = Paragraph(
    "Report prepared by: %s, %s"
    % (blpt_data["requestor_name"], blpt_data["requestor_company"]),
    styles["Normal"],
)
prepare_line2 = Paragraph(
    "Report prepared on: %s" % (blpt_data["prepare_date"]), styles["Normal"]
)

# Send the data and build the file
elements.append(title)
elements.append(recipient)
elements.append(prepare_line)
elements.append(prepare_line2)
elements.append(Spacer(0, 10))
elements.append(t)

# Build the file
doc.build(elements)
