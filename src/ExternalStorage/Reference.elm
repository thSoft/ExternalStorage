module ExternalStorage.Reference (
  Reference,
  Error(..),
  create,
  decoder) where

{-|
# Referring values in a cache
@docs Reference, Error, create, decoder
-}

import Dict
import Result exposing (..)
import Result
import Json.Decode exposing (..)
import Json.Decode as Decode
import ExternalStorage.Cache exposing (..)

{-| A type-safe remote reference which can be resolved lazily with its `get` function.

    type alias Book = {
      title: String,
      authors: List (Reference Writer)
    }
-}
type alias Reference a = {
  url: String,
  get: Result Error a
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
The object is looked up from the given cache and decoded with the given decoder.

    book : Signal (Reference Book)
    book =
      let load cache = Reference.create (bookDecoder cache) bookUrl cache
      in Signal.map load cache
-}
create : Decoder a -> String -> Cache -> Reference a
create decoder url cache =
  {
    url = url,
    get =
      case cache |> Dict.get url of
        Just value -> value |> decodeValue decoder |> formatError DecodingFailed
        Nothing -> Result.Err NotFound
  }

{-| Decodes a JavaScript string to a remote reference with the string as URL.

    bookDecoder : Cache -> Decoder Book
    bookDecoder cache =
      object2 Book
        ("title" := string)
        ("authors" := list (decoder writerDecoder cache))
-}
decoder : Decoder a -> Cache -> Decoder (Reference a)
decoder decoder cache = string |> Decode.map (\url -> create decoder url cache)
