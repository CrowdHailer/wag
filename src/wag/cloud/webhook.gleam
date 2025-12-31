import gleam/dynamic/decode
import gleam/http/request
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/result
import wag/cloud/contact_information.{type ContactInformation}
import wag/decodex.{optional_field, sparse}

pub type Verified {
  Failed
  Success(challenge: String)
  Continue
}

pub fn verify(request, config) {
  let query = request.get_query(request) |> result.unwrap([])
  case list.key_find(query, "hub.mode") {
    Ok("subscribe") ->
      case list.key_find(query, "hub.verify_token") {
        Ok(token) if token == config -> {
          let challenge =
            list.key_find(query, "hub.challenge") |> result.unwrap("")
          Success(challenge:)
        }
        _ -> Failed
      }
    _ -> Continue
  }
}

// https://developers.facebook.com/docs/whatsapp/cloud-api/webhooks/components/
pub fn decoder() {
  decodex.discriminate("object", decode.string, [], fn(object) {
    case object {
      "whatsapp_business_account" ->
        Ok(decode.field("entry", decode.list(entry_decoder()), decode.success))
      _ -> Error("Unknown object: " <> object)
    }
  })
}

// https://developers.facebook.com/docs/whatsapp/business-management-api/webhooks/components
pub type Entry {
  Entry(id: String, changes: List(Change))
}

fn entry_decoder() {
  use id <- decode.field("id", decode.string)
  use changes <- decode.field("changes", decode.list(change_decoder()))
  decode.success(Entry(id:, changes:))
}

pub type Change {
  IncomingMessages(
    metadata: Metadata,
    contacts: List(Contact),
    messages: List(Message),
  )
  StatusMessages(metadata: Metadata, statuses: List(Status))
}

fn change_decoder() {
  let zero = IncomingMessages(Metadata("", ""), [], [])
  decodex.discriminate("field", decode.string, zero, fn(field) {
    case field {
      "messages" ->
        Ok(decode.field(
          "value",
          decode.one_of(incoming_messages_decoder(), [status_messages_decoder()]),
          decode.success,
        ))
      _ -> {
        Error("Unknown field: " <> field)
      }
    }
  })
}

fn incoming_messages_decoder() {
  use metadata <- decode.field("metadata", metadata_decoder())
  use contacts <- decode.field("contacts", decode.list(contact_decoder()))
  use messages <- decode.field("messages", decode.list(message_decoder()))
  decode.success(IncomingMessages(metadata:, contacts:, messages:))
}

fn status_messages_decoder() {
  use metadata <- decode.field("metadata", metadata_decoder())
  use statuses <- decode.field("statuses", decode.list(status_decoder()))
  decode.success(StatusMessages(metadata:, statuses:))
}

pub type Contact {
  Contact(profile: Profile, wa_id: String)
}

fn contact_decoder() {
  use profile <- decode.field("profile", profile_decoder())
  use wa_id <- decode.field("wa_id", decode.string)
  decode.success(Contact(profile:, wa_id:))
}

pub type Profile {
  Profile(name: String)
}

fn profile_decoder() {
  use name <- decode.field("name", decode.string)
  decode.success(Profile(name:))
}

pub type Metadata {
  Metadata(display_phone_number: String, phone_number_id: String)
}

fn metadata_decoder() {
  use display_phone_number <- decode.field(
    "display_phone_number",
    decode.string,
  )
  use phone_number_id <- decode.field("phone_number_id", decode.string)
  decode.success(Metadata(display_phone_number:, phone_number_id:))
}

// https://developers.facebook.com/docs/whatsapp/cloud-api/webhooks/reference/messages

pub type Message {
  Message(from: String, id: String, timestamp: String, payload: MessagePayload)
}

pub fn message_decoder() {
  use from <- decode.field("from", decode.string)
  use id <- decode.field("id", decode.string)
  use timestamp <- decode.field("timestamp", decode.string)
  use payload <- decode.then(payload_decoder())
  decode.success(Message(from:, id:, timestamp:, payload:))
}

pub fn encode_message(message) {
  let Message(from:, id:, timestamp:, payload:) = message
  let #(type_, payload) = encode_payload(payload)
  json.object([
    #("from", json.string(from)),
    #("id", json.string(id)),
    #("timestamp", json.string(timestamp)),
    #("type", json.string(type_)),
    #(type_, payload),
  ])
}

pub type MessagePayload {
  Audio(mime_type: String, sha256: String, id: String, voice: Bool)
  Button(payload: String, text: String)
  Contacts(List(ContactInformation))
  Document(
    caption: Option(String),
    filename: String,
    mime_type: String,
    sha256: String,
    id: String,
  )
  Image(caption: Option(String), mime_type: String, sha256: String, id: String)
  Location(
    address: Option(String),
    latitude: Float,
    longitude: Float,
    name: Option(String),
    url: Option(String),
  )
  Reaction(message_id: String, emoji: String)
  Sticker(mime_type: String, sha256: String, id: String, animated: Bool)
  Text(text: String)
  Video(caption: Option(String), mime_type: String, sha256: String, id: String)
}

pub fn payload_decoder() {
  decodex.discriminate("type", decode.string, Text(""), fn(type_) {
    case type_ {
      "audio" -> Ok(audio_decoder())
      "button" -> Ok(button_decoder())
      "contacts" -> Ok(contacts_decoder())
      "document" -> Ok(document_decoder())
      "image" -> Ok(image_decoder())
      "location" -> Ok(location_decoder())
      "reaction" -> Ok(reaction_decoder())
      "sticker" -> Ok(sticker_decoder())
      "text" -> Ok(text_decoder())
      "video" -> Ok(video_decoder())
      _ -> Error("Unknown message payload type: " <> type_)
    }
  })
}

fn audio_decoder() {
  use audio <- decode.field("audio", {
    use mime_type <- decode.field("mime_type", decode.string)
    use sha256 <- decode.field("sha256", decode.string)
    use id <- decode.field("id", decode.string)
    use voice <- decode.field("voice", decode.bool)
    decode.success(Audio(mime_type:, sha256:, id:, voice:))
  })
  decode.success(audio)
}

fn button_decoder() {
  use button <- decode.field("button", {
    use payload <- decode.field("payload", decode.string)
    use text <- decode.field("text", decode.string)
    decode.success(Button(payload:, text:))
  })
  decode.success(button)
}

fn contacts_decoder() {
  use contacts <- decode.field(
    "contacts",
    decode.list(contact_information.decoder()),
  )
  decode.success(Contacts(contacts))
}

fn document_decoder() {
  use document <- decode.field("document", {
    use caption <- optional_field("caption", decode.string)
    use filename <- decode.field("filename", decode.string)
    use mime_type <- decode.field("mime_type", decode.string)
    use sha256 <- decode.field("sha256", decode.string)
    use id <- decode.field("id", decode.string)
    decode.success(Document(caption:, filename:, mime_type:, sha256:, id:))
  })
  decode.success(document)
}

fn image_decoder() {
  use image <- decode.field("image", {
    use caption <- optional_field("caption", decode.string)
    use mime_type <- decode.field("mime_type", decode.string)
    use sha256 <- decode.field("sha256", decode.string)
    use id <- decode.field("id", decode.string)
    decode.success(Image(caption:, mime_type:, sha256:, id:))
  })
  decode.success(image)
}

fn location_decoder() {
  use location <- decode.field("location", {
    use address <- optional_field("address", decode.string)
    use latitude <- decode.field("latitude", decode.float)
    use longitude <- decode.field("longitude", decode.float)
    use name <- optional_field("name", decode.string)
    use url <- optional_field("url", decode.string)
    decode.success(Location(address:, latitude:, longitude:, name:, url:))
  })
  decode.success(location)
}

fn reaction_decoder() {
  use reaction <- decode.field("reaction", {
    use emoji <- decode.field("emoji", decode.string)
    use message_id <- decode.field("message_id", decode.string)
    decode.success(Reaction(emoji:, message_id:))
  })
  decode.success(reaction)
}

fn sticker_decoder() {
  use sticker <- decode.field("sticker", {
    use mime_type <- decode.field("mime_type", decode.string)
    use sha256 <- decode.field("sha256", decode.string)
    use id <- decode.field("id", decode.string)
    use animated <- decode.field("animated", decode.bool)
    decode.success(Sticker(mime_type:, sha256:, id:, animated:))
  })
  decode.success(sticker)
}

fn text_decoder() {
  use body <- decode.field("text", {
    use body <- decode.field("body", decode.string)
    decode.success(body)
  })
  decode.success(Text(body))
}

fn video_decoder() {
  use audio <- decode.field("audio", {
    use mime_type <- decode.field("mime_type", decode.string)
    use sha256 <- decode.field("sha256", decode.string)
    use id <- decode.field("id", decode.string)
    use voice <- decode.field("voice", decode.bool)
    decode.success(Audio(mime_type:, sha256:, id:, voice:))
  })
  decode.success(audio)
}

pub fn encode_payload(payload) {
  case payload {
    Audio(mime_type:, sha256:, id:, voice:) -> #(
      "audio",
      sparse([
        #("mime_type", json.string(mime_type)),
        #("sha256", json.string(sha256)),
        #("id", json.string(id)),
        #("voice", json.bool(voice)),
      ]),
    )
    Button(payload:, text:) -> #(
      "button",
      sparse([#("payload", json.string(payload)), #("text", json.string(text))]),
    )
    Contacts(contacts) -> #(
      "contacts",
      json.array(contacts, contact_information.encode),
    )
    Document(caption:, filename:, sha256:, mime_type:, id:) -> #(
      "document",
      sparse([
        #("caption", json.nullable(caption, json.string)),
        #("filename", json.string(filename)),
        #("sha256", json.string(sha256)),
        #("mime_type", json.string(mime_type)),
        #("id", json.string(id)),
      ]),
    )
    Image(caption:, mime_type:, sha256:, id:) -> #(
      "image",
      sparse([
        #("caption", json.nullable(caption, json.string)),
        #("mime_type", json.string(mime_type)),
        #("sha256", json.string(sha256)),
        #("id", json.string(id)),
      ]),
    )
    Location(latitude:, longitude:, name:, address:, url:) -> #(
      "location",
      sparse([
        #("address", json.nullable(address, json.string)),
        #("latitude", json.float(latitude)),
        #("longitude", json.float(longitude)),
        #("name", json.nullable(name, json.string)),
        #("url", json.nullable(url, json.string)),
      ]),
    )
    Reaction(message_id:, emoji:) -> #(
      "reaction",
      sparse([
        #("message_id", json.string(message_id)),
        #("emoji", json.string(emoji)),
      ]),
    )
    Sticker(mime_type:, sha256:, id:, animated:) -> #(
      "sticker",
      sparse([
        #("mime_type", json.string(mime_type)),
        #("sha256", json.string(sha256)),
        #("id", json.string(id)),
        #("animated", json.bool(animated)),
      ]),
    )
    Text(text) -> #("text", json.object([#("body", json.string(text))]))
    Video(caption, mime_type, sha256, id) -> #(
      "video",
      sparse([
        #("caption", json.nullable(caption, json.string)),
        #("mime_type", json.string(mime_type)),
        #("sha256", json.string(sha256)),
        #("id", json.string(id)),
      ]),
    )
  }
}

pub type Status {
  Status(id: String, status: String, timestamp: String, recipient_id: String)
}

fn status_decoder() {
  use id <- decode.field("id", decode.string)
  use status <- decode.field("status", decode.string)
  use timestamp <- decode.field("timestamp", decode.string)
  use recipient_id <- decode.field("recipient_id", decode.string)
  decode.success(Status(id:, status:, timestamp:, recipient_id:))
}
