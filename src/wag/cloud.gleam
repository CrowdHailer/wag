import gleam/bit_array
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/http/response.{Response}
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/string
import wag/cloud/contact_information
import wag/decodex

const api_host = "graph.facebook.com"

const api_version = "v22.0"

fn base_request(token) {
  request.new()
  |> request.set_host(api_host)
  |> request.prepend_header("Authorization", string.append("Bearer ", token))
  |> request.set_body(<<>>)
}

fn get(token, path) {
  base_request(token)
  |> request.set_path("/" <> api_version <> path)
}

fn post(token, path, mime, content) {
  base_request(token)
  |> request.set_method(http.Post)
  |> request.set_path("/" <> api_version <> path)
  |> request.prepend_header("content-type", mime)
  |> request.set_body(content)
}

pub type Message {
  Audio(media: Media)
  Contacts(contacts: List(contact_information.ContactInformation))
  Document(source: Source, filename: String, caption: Option(String))
  Image(media: Media)
  Interactive(Interactive)
  Location(
    latitude: Float,
    longitude: Float,
    name: Option(String),
    address: Option(String),
  )
  Sticker(source: Source)
  Template(name: String, language: String, components: List(Component))
  Text(body: String, preview_url: Bool)
  Video(media: Media)
}

pub type Media {
  Media(source: Source, caption: Option(String))
}

pub type Source {
  Ref(id: String)
  Link(link: String)
}

fn source_to_entry(source) {
  case source {
    Ref(id) -> #("id", json.string(id))
    Link(link) -> #("link", json.string(link))
  }
}

pub type Component {
  Body(text: String)
}

// biz_opaque_callback_data
// context for reply
fn message_to_fields(message) {
  let #(type_, contents): #(String, json.Json) =
    message_to_type_and_contents(message)

  [
    #("messaging_product", json.string("whatsapp")),
    #("recipient_type", json.string("individual")),
    #("type", json.string(type_)),
    #(type_, contents),
  ]
}

fn message_to_type_and_contents(message) {
  case message {
    Audio(media) -> #("audio", media_to_json(media))
    Contacts(contacts) -> #(
      "contacts",
      json.array(contacts, contact_information.encode),
    )
    Document(source:, filename:, caption:) -> #(
      "document",
      decodex.sparse([
        source_to_entry(source),
        #("filename", json.string(filename)),
        #("caption", json.nullable(caption, json.string)),
      ]),
    )
    Image(media) -> #("image", media_to_json(media))
    Interactive(interactive) -> #(
      "interactive",
      interactive_to_json(interactive),
    )
    Location(latitude:, longitude:, name:, address:) -> #(
      "location",
      decodex.sparse([
        #("latitude", json.float(latitude)),
        #("longitude", json.float(longitude)),
        #("name", json.nullable(name, json.string)),
        #("address", json.nullable(address, json.string)),
      ]),
    )
    Sticker(source:) -> #("sticker", decodex.sparse([source_to_entry(source)]))
    Template(name:, language:, components:) -> #(
      "template",
      json.object([
        #("name", json.string(name)),
        #("language", json.object([#("code", json.string(language))])),
        #(
          "components",
          json.array(components, fn(_) { todo as "understand components" }),
        ),
      ]),
    )
    Text(body:, preview_url:) -> #(
      "text",
      json.object([
        #("body", json.string(body)),
        #("preview_url", json.bool(preview_url)),
      ]),
    )
    Video(media) -> #("video", media_to_json(media))
  }
}

fn media_to_json(media) {
  let Media(source:, caption:) = media
  let source = case source {
    Ref(id) -> #("id", json.string(id))
    Link(link) -> #("link", json.string(link))
  }
  json.object(case caption {
    Some(caption) -> [source, #("caption", json.string(caption))]
    None -> [source]
  })
}

pub type Interactive {
  ReplyButtons(
    header: Option(Source),
    body: String,
    footer: Option(String),
    buttons: List(ReplyButton),
  )
  CtaUrl(
    header: Option(Source),
    body: String,
    footer: Option(String),
    cta_text: String,
    cta_url: String,
  )
}

fn interactive_to_json(interactive) {
  case interactive {
    ReplyButtons(header:, body:, footer:, buttons:) ->
      decodex.sparse([
        #("type", json.string("button")),
        // Not just media as text is an option
        #("header", json.nullable(header, fn(source) { todo })),
        #("body", json.object([#("text", json.string(body))])),
        #(
          "footer",
          json.nullable(footer, fn(text) {
            json.object([#("text", json.string(text))])
          }),
        ),
        #(
          "action",
          json.object([#("buttons", json.array(buttons, button_to_json))]),
        ),
      ])
    CtaUrl(header:, body:, footer:, cta_text:, cta_url:) ->
      decodex.sparse([
        #("type", json.string("cta_url")),
        // Not just media as text is an option
        #("header", json.nullable(header, fn(source) { todo })),
        #("body", json.object([#("text", json.string(body))])),
        #(
          "footer",
          json.nullable(footer, fn(text) {
            json.object([#("text", json.string(text))])
          }),
        ),
        #(
          "action",
          json.object([
            #("name", json.string("cta_url")),
            #(
              "parameters",
              json.object([
                #("display_text", json.string(cta_text)),
                #("url", json.string(cta_url)),
              ]),
            ),
          ]),
        ),
      ])
  }
}

pub type ReplyButton {
  ReplyButton(id: String, title: String)
}

pub fn button_to_json(button) {
  let ReplyButton(id:, title:) = button
  json.object([
    #("type", json.string("reply")),
    #(
      "reply",
      json.object([#("id", json.string(id)), #("title", json.string(title))]),
    ),
  ])
}

// TODO add context
pub fn send_message_request(token, from, to, message) {
  let payload = [#("to", json.string(to)), ..message_to_fields(message)]
  do_send_message_request(token, from, payload)
}

pub fn send_typing_indicator(token, from, message_id, indicate_typing) {
  let payload = [
    #("messaging_product", json.string("whatsapp")),
    #("status", json.string("read")),
    #("message_id", json.string(message_id)),
    case indicate_typing {
      True -> #(
        "typing_indicator",
        json.object([#("type", json.string("text"))]),
      )
      False -> #("typing_indicator", json.null())
    },
  ]
  do_send_message_request(token, from, payload)
}

fn do_send_message_request(token, from, payload) {
  post(
    token,
    "/" <> from <> "/messages",
    "application/json",
    json.to_string(decodex.sparse(payload)) |> bit_array.from_string,
  )
}

pub type Contact {
  Contact(input: String, wa_id: String)
}

pub fn send_message_response(response) {
  let Response(status:, body:, ..) = response
  case status {
    200 -> {
      let assert Ok(response) =
        json.parse_bits(body, {
          use contacts <- decode.field(
            "contacts",
            decode.list({
              use input <- decode.field("input", decode.string)
              use wa_id <- decode.field("wa_id", decode.string)
              decode.success(Contact(input, wa_id))
            }),
          )
          use messages <- decode.field(
            "messages",
            decode.list({
              use id <- decode.field("id", decode.string)
              // use message_status <- decode.field(
              //   "message_status",
              //   decode.string,
              // )
              decode.success(id)
            }),
          )

          decode.success(#(contacts, messages))
        })
      Ok(response)
    }
    _ -> Error(body)
  }
}

pub fn retreive_media_request(token, media_id) {
  get(token, "/" <> media_id)
}

pub fn retreive_media_response(response) {
  let Response(status:, body:, ..) = response
  let decoder = decode.field("url", decode.string, decode.success)
  case status {
    200 ->
      case json.parse_bits(body, decoder) {
        Ok(url) -> Ok(url)
        Error(_) -> Error(body)
      }
    _ -> Error(body)
  }
}
