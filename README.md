# wag

[![Package Version](https://img.shields.io/hexpm/v/wag)](https://hex.pm/packages/wag)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/wag/)

## Overview

### Cloud API
Send and receive messages using a cloud-hosted version of the WhatsApp Business Platform.

You will need:
- A Meta developer account
- An App, add whatsapp as a product
- A business portfolio Not the same as a business asset

```sh
gleam add wag@1
```
```gleam
import wag

pub fn main() -> Nil {
  // TODO: An example of the project in use
}
```

Further documentation can be found at <https://hexdocs.pm/wag>.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```

```
WHATSAPP_TOKEN=token WHATSAPP_SENDER=business_number gleam dev recipient_number
```

## Setup
https://developers.facebook.com/apps/

