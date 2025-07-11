import gleam/fetch
import gleam/javascript/array.{type Array}
import gleam/javascript/promise
import gleam/option.{None, Some}
import wag/cloud
import wag/cloud/contact_information

@external(javascript, "./wag_dev_ffi.mjs", "env")
fn env(key: String) -> Result(String, Nil)

@external(javascript, "./wag_dev_ffi.mjs", "args")
fn args() -> Array(String)

fn load(key) {
  case env(key) {
    Ok(value) -> value
    Error(Nil) -> panic as { "missing env var: " <> key }
  }
}

pub fn main() {
  let token = load("WHATSAPP_TOKEN")
  let sender = load("WHATSAPP_SENDER")
  let assert [_node, _script, ..args] = array.to_list(args())
  case args {
    [recipient] -> run(token, sender, recipient)
    _ -> panic as "expected recipient number"
  }
}

fn run(token, sender, recipient) {
  // let message = cloud.Text("hello", False)
  let message =
    cloud.Contacts([
      contact_information.ContactInformation(
        addresses: [],
        birthday: None,
        emails: [],
        name: contact_information.Name(
          formatted_name: "John Doe",
          first_name: Some("John"),
          last_name: Some("Doe"),
          middle_name: None,
          suffix: None,
          prefix: None,
        ),
        org: None,
        phones: [
          contact_information.Phone(
            phone: "1234567890",
            type_: Some("home"),
            wa_id: None,
          ),
        ],
        urls: [],
      ),
    ])
  let message =
    cloud.Document(
      cloud.Link(
        "https://raw.githubusercontent.com/CrowdHailer/eyg-lang/refs/heads/main/README.md",
      ),
      "README.md",
      Some("The future of programming."),
    )
  let message =
    cloud.Location(
      latitude: 0.0,
      longitude: 0.0,
      name: Some("null island"),
      address: None,
    )
  let message =
    cloud.Interactive(
      cloud.ReplyButtons(None, "Let's play a game", Some("go for it"), [
        cloud.ReplyButton("rock", "Rock"),
        cloud.ReplyButton("paper", "Paper"),
        cloud.ReplyButton("scissors", "Scissors"),
      ]),
    )
  let message =
    cloud.Interactive(cloud.CtaUrl(
      header: None,
      body: "EYG is the language for automation",
      footer: Some("Built with Gleam"),
      cta_text: "Check it out",
      cta_url: "https://eyg.run",
    ))
  let request = cloud.send_message_request(token, sender, recipient, message)
  use response <- promise.try_await(fetch.send_bits(request))
  use response <- promise.try_await(fetch.read_json_body(response))
  echo response.status
  echo response.body
  promise.resolve(Ok(Nil))
}
