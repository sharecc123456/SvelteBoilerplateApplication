
"""Add an HTTP header to each response."""


class AddHeader:
    def __init__(self):
        print("initialized blpt nomad proxy")

    def request(self, flow):
        flow.request.headers["x-boilerplate-api-key"] = "798076dc8fcec583db486d4d2092a63f749cc8118000990296dec62e7e9486ce"


addons = [
    AddHeader()
]
