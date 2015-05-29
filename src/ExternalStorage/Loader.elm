module ExternalStorage.Loader (
  Remote,
  Error(..),
  load,
  loadRaw) where

{-|
# Building your model from a cache
@docs Remote, Error, load, loadRaw
-}

import Dict
import Result exposing (..)
import Result
import Json.Decode exposing (..)
import Json.Decode as Decode
import ExternalStorage.Cache exposing (..)

{-| Associates an URL to an object.

    type alias Book = {
      title: String,
      author: Remote Writer
    }
-}
type alias Remote a = { a | url: String }

{-| The various error cases that might happen when loading an object from a cache.

    viewError url error =
      case error of
        NotFound { url } -> "Loading " ++ url
        DecodingFailed { url, message } -> "Can't decode " ++ url + ": " ++ message
-}
type Error =
  NotFound (Remote {}) |
  DecodingFailed (Remote {
    message: String
  })

makeNotFound : String -> Error
makeNotFound url = NotFound { url = url }

makeDecodingFailed : String -> String -> Error
makeDecodingFailed url message =
  DecodingFailed {
    url = url,
    message = message
  }

{-| Loads a subtree of your model starting from an object.
Finds the JSON value belonging to the given URL in the given cache,
then decodes it to a raw object using the given decoder,
then parses the raw object to the real object using the given parser function.
The raw object is like the real one regarding attributes,
but contains URLs instead of object references.
The parser should resolve the URLs in the raw objects to real objects from the cache using their loader functions.

    loadBook : Cache -> String -> Result Error (Remote Book)
    loadBook cache url = load cache rawBookDecoder parseBook url

    rawBookDecoder : Decoder RawBook
    rawBookDecoder =
      object2 RawBook
        ("title" := string)
        ("author" := string)

    parseBook : Cache -> RawBook -> Result Error Book
    parseBook cache rawBook =
      let authorResult = rawBook.author |> loadWriter cache
      in
        authorResult |> Result.map (\author ->
          {
            title = rawBook.title,
            author = author
          }
        )

    type alias RawBook = {
      title: String,
      author: String
    }
-}
load : Cache -> Decoder rawObject -> (Cache -> rawObject -> Result Error object) -> String -> Result Error (Remote object)
load cache rawObjectDecoder parseObject url =
  let maybeValue = cache |> Dict.get url
      valueResult = maybeValue |> fromMaybe (makeNotFound url)
      rawObjectResult = valueResult `Result.andThen` (\value -> value |> decodeValue rawObjectDecoder |> formatError (makeDecodingFailed url))
      objectResult = rawObjectResult `Result.andThen` (parseObject cache)
  in objectResult |> Result.map (\object -> { object | url = url })

{-| Loads a single model object which contains only attributes but no references to further model objects.
Finds the JSON value belonging to the given URL in the given cache,
then decodes it to an object using the given decoder.

    loadWriter : Cache -> String -> Result Error (Remote Writer)
    loadWriter cache url = loadRaw cache writerDecoder url

    type alias Writer = {
      name: String
    }

    writerDecoder : Decoder Writer
    writerDecoder =
      object1 Writer
        ("name" := string)
-}
loadRaw : Cache -> Decoder object -> String -> Result Error (Remote object)
loadRaw cache objectDecoder url =
  let parseObject _ rawObject = Result.Ok rawObject
  in load cache objectDecoder parseObject url
