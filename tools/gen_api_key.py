#!/usr/bin/python3
import uuid

# Generates an API key
env = "live"
prefix = "blpt"

apikey = str(uuid.uuid4()).replace("-", "")

print("%s.%s.%s" % (prefix, env, apikey))
