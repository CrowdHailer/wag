import { Ok, Error } from "./gleam.mjs";

export function args(){
  return process.argv
}

export function env(key) {
  const value = process.env[key]
  if (value == null) {
    return new Error()
  } else {
    return new Ok(value)
  }
}