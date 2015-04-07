module ExternalStorage.Reference (
  Reference,
  Error(NotFound, DecodingFailed),
  create,
  decoder) where

{-|
# Referring values in a cache
@docs Reference, Error, create, decoder
-}

import Dict
import Result (..)
import Result
import Json.Decode (..)
import Json.Decode as Decode
import ExternalStorage.Cache (..)

{-| A type-safe remote reference which can be resolved lazily with its `get` function.

    type alias Book = {
      title: String,
      authors: List (Reference Writer)
    }
-}
type alias Reference a = {
  url: String,
  get: Cache -> Result Error a
}

{-| The various error cases that might happen when dereferencing an object.

    viewError url error =
      case error of
        NotFound -> "Loading " ++ url
        DecodingFailed message -> "Can't decode " ++ url ++ ": " ++ message
-}
type Error =
  NotFound |
  DecodingFailed String

{-| Creates a reference to the object at the given URL.
The object will be looked up from an arbitrary cache and decoded with the given decoder.

    book : Reference Book
    book = "http://example.com/book" |> create bookDecoder
-}
create : Decoder a -> String -> Reference a
create decoder url =
  {
    url = url,
    get = \cache ->
      case cache |> Dict.get url of
        Just value -> value |> decodeValue decoder |> formatError DecodingFailed
        Nothing -> Result.Err NotFound
  }

{-| Decodes a JavaScript string to a remote reference.

    bookDecoder =
      object2 Book
        ("title" := string)
        ("authors" := list (decoder writerDecoder))
-}
decoder : Decoder a -> Decoder (Reference a)
decoder decoder = string |> Decode.map (create decoder)