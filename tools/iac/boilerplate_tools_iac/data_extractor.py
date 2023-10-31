#!/usr/bin/env python
# Copyright 2020-2022 (c) Boilerplate, Inc.
# Author: Levente Kurusa <lev@boilerplate.co>
#
# parse BP-generated PDFs to get information
from pdfrw import PdfReader
from pdfrw import uncompress
import sys
import zlib

file_name = sys.argv[1]
reader = PdfReader(file_name)

def parse_bpsig_flatedecode(s):
    f = [s]
    uncompress.uncompress(f)
    print(f[0].stream)

def parse_bpsig(filespec):
    ef = filespec.EF.F
    the_stream = ef.stream
    if ef.Filter == '/FlateDecode':
        parse_bpsig_flatedecode(ef)
    else:
        print("ERROR: invalid encoding of signature: " + ef.Filter)

def parse(filespec):
    if (filespec.F) == '(__boilerplate_signature)':
        parse_bpsig(filespec)

root = reader.Root
names = root.Names
if not (names is None):
    ef = names.EmbeddedFiles
    if not (ef is None):
        # loop throught the name tree
        z = zip(*[ef.Names[i::2] for i in range(2)]) 
        for (k, v) in z:
            parse(v)
