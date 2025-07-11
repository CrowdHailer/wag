import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{None, Some}

pub fn sparse(entries: List(#(String, json.Json))) -> json.Json {
  list.filter(entries, fn(entry) {
    let #(_, v) = entry
    v != json.null()
  })
  |> json.object
}

pub fn optional_field(field, decoder, then) {
  decode.optional_field(field, None, decode.map(decoder, Some), then)
}

pub fn default_field(field, default, decoder, then) {
  decode.optional_field(field, default, decoder, then)
}
