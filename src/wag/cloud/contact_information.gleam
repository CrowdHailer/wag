import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option}
import wag/decodex.{default_field, optional_field}

pub type ContactInformation {
  ContactInformation(
    addresses: List(Address),
    birthday: Option(String),
    emails: List(Email),
    name: Name,
    org: Option(Org),
    phones: List(Phone),
    urls: List(Url),
  )
}

pub fn decoder() {
  use addresses <- default_field(
    "addresses",
    [],
    decode.list(address_decoder()),
  )
  use birthday <- optional_field("birthday", decode.string)
  use emails <- default_field("emails", [], decode.list(email_decoder()))
  use name <- decode.field("name", name_decoder())
  use org <- optional_field("org", org_decoder())
  use phones <- default_field("phones", [], decode.list(phone_decoder()))
  use urls <- default_field("urls", [], decode.list(url_decoder()))
  decode.success(ContactInformation(
    addresses:,
    birthday:,
    emails:,
    name:,
    org:,
    phones:,
    urls:,
  ))
}

pub fn encode(contact_information) {
  let ContactInformation(addresses, birthday, emails, name, org, phones, urls) =
    contact_information
  decodex.sparse([
    #("addresses", json.array(addresses, address_encode)),
    #("birthday", json.nullable(birthday, json.string)),
    #("emails", json.array(emails, email_encode)),
    #("name", name_encode(name)),
    #("org", json.nullable(org, org_encode)),
    #("phones", json.array(phones, phone_encode)),
    #("urls", json.array(urls, url_encode)),
  ])
}

pub type Address {
  Address(
    city: Option(String),
    country: Option(String),
    country_code: Option(String),
    state: Option(String),
    street: Option(String),
    type_: Option(String),
    zip: Option(String),
  )
}

fn address_decoder() {
  use city <- optional_field("city", decode.string)
  use country <- optional_field("country", decode.string)
  use country_code <- optional_field("country_code", decode.string)
  use state <- optional_field("state", decode.string)
  use street <- optional_field("street", decode.string)
  use type_ <- optional_field("type", decode.string)
  use zip <- optional_field("zip", decode.string)
  decode.success(Address(
    city:,
    country:,
    country_code:,
    state:,
    street:,
    type_:,
    zip:,
  ))
}

fn address_encode(address) {
  let Address(city:, country:, country_code:, state:, street:, type_:, zip:) =
    address
  json.object([
    #("city", json.nullable(city, json.string)),
    #("country", json.nullable(country, json.string)),
    #("country_code", json.nullable(country_code, json.string)),
    #("state", json.nullable(state, json.string)),
    #("street", json.nullable(street, json.string)),
    #("type", json.nullable(type_, json.string)),
    #("zip", json.nullable(zip, json.string)),
  ])
}

pub type Email {
  Email(email: String, type_: Option(String))
}

fn email_decoder() {
  use email <- decode.field("email", decode.string)
  use type_ <- optional_field("type", decode.string)
  decode.success(Email(email, type_))
}

fn email_encode(email) {
  let Email(email:, type_:) = email
  decodex.sparse([
    #("email", json.string(email)),
    #("type", json.nullable(type_, json.string)),
  ])
}

pub type Name {
  Name(
    formatted_name: String,
    first_name: Option(String),
    last_name: Option(String),
    middle_name: Option(String),
    suffix: Option(String),
    prefix: Option(String),
  )
}

fn name_decoder() {
  use formatted_name <- decode.field("formatted_name", decode.string)
  use first_name <- optional_field("first_name", decode.string)
  use last_name <- optional_field("last_name", decode.string)
  use middle_name <- optional_field("middle_name", decode.string)
  use suffix <- optional_field("suffix", decode.string)
  use prefix <- optional_field("prefix", decode.string)
  decode.success(Name(
    formatted_name,
    first_name,
    last_name,
    middle_name,
    suffix,
    prefix,
  ))
}

fn name_encode(name) {
  let Name(
    formatted_name:,
    first_name:,
    last_name:,
    middle_name:,
    suffix:,
    prefix:,
  ) = name
  decodex.sparse([
    #("formatted_name", json.string(formatted_name)),
    #("first_name", json.nullable(first_name, json.string)),
    #("last_name", json.nullable(last_name, json.string)),
    #("middle_name", json.nullable(middle_name, json.string)),
    #("suffix", json.nullable(suffix, json.string)),
    #("prefix", json.nullable(prefix, json.string)),
  ])
}

pub type Org {
  Org(
    company: Option(String),
    department: Option(String),
    title: Option(String),
  )
}

fn org_decoder() {
  use company <- optional_field("company", decode.string)
  use department <- optional_field("department", decode.string)
  use title <- optional_field("title", decode.string)
  decode.success(Org(company, department, title))
}

fn org_encode(org) {
  let Org(company:, department:, title:) = org
  decodex.sparse([
    #("company", json.nullable(company, json.string)),
    #("department", json.nullable(department, json.string)),
    #("title", json.nullable(title, json.string)),
  ])
}

pub type Phone {
  Phone(phone: String, type_: Option(String), wa_id: Option(String))
}

fn phone_decoder() {
  use phone <- decode.field("phone", decode.string)
  use type_ <- optional_field("type", decode.string)
  use wa_id <- optional_field("wa_id", decode.string)
  decode.success(Phone(phone, type_, wa_id))
}

fn phone_encode(phone) {
  let Phone(phone:, type_:, wa_id:) = phone
  decodex.sparse([
    #("phone", json.string(phone)),
    #("type", json.nullable(type_, json.string)),
    #("wa_id", json.nullable(wa_id, json.string)),
  ])
}

pub type Url {
  Url(url: String, type_: Option(String))
}

fn url_decoder() {
  use url <- decode.field("url", decode.string)
  use type_ <- optional_field("type", decode.string)
  decode.success(Url(url, type_))
}

fn url_encode(url) {
  let Url(url:, type_:) = url
  decodex.sparse([
    #("url", json.string(url)),
    #("type", json.nullable(type_, json.string)),
  ])
}
