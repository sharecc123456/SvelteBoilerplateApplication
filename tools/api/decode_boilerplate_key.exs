#!/usr/bin/env elixir

cookie = IO.read(:stdio, :eof)
[_, payload, _] = String.split(cookie, ".", parts: 3)
{:ok, encoded_term } = Base.url_decode64(payload, padding: false)
data = :erlang.binary_to_term(encoded_term)
IO.puts(data["guardian_default_token"])
