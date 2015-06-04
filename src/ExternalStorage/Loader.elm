module ExternalStorage.Loader (
  Remote,
  Error(..),
  load,
  loadRaw,
  loadList) where

{-|
# Building your model from a cache
@docs Remote, Error, load, loadRaw, loadList
-}

import Dict
import Result exposing (..)
import Result
import Json.Decode exposing (..)
import Json.Decode as Decode
import ExternalStorage.Cache exposing (..)

{-| The result of loading from a cache.

    model : Signal (Loaded Library)
-}
type alias Loaded a = Result Error (Remote a)

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
then resolves the raw object to the real object using the given resolver function.
The raw object is like the real one regarding attributes,
but contains URLs instead of object references.
The resolver should resolve the URLs in the raw objects to real objects from the cache using their loader functions.

    loadBook : Cache -> String -> Loaded Book
    loadBook cache url = load cache rawBookDecoder resolveBook url

    rawBookDecoder : Decoder RawBook
    rawBookDecoder =
      object2 RawBook
        ("title" := string)
        ("author" := string)

    resolveBook : Cache -> RawBook -> Result Error Book
    resolveBook cache rawBook =
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
load : Cache -> Decoder rawObject -> (Cache -> rawObject -> Result Error object) -> String -> Loaded object
load cache rawObjectDecoder resolveObject url =
  let maybeValue = cache |> Dict.get url
      valueResult = maybeValue |> fromMaybe (makeNotFound url)
      rawObjectResult = valueResult `Result.andThen` (\value -> value |> decodeValue rawObjectDecoder |> formatError (makeDecodingFailed url))
      objectResult = rawObjectResult `Result.andThen` (resolveObject cache)
  in objectResult |> Result.map (\object -> { object | url = url })

{-| Loads a single model object which contains only attributes but no references to further model objects.
Finds the JSON value belonging to the given URL in the given cache,
then decodes it to an object using the given decoder.

    loadWriter : Cache -> String -> Loaded Writer
    loadWriter cache url = loadRaw cache writerDecoder url

    type alias Writer = {
      name: String
    }

    writerDecoder : Decoder Writer
    writerDecoder =
      object1 Writer
        ("name" := string)
-}
loadRaw : Cache -> Decoder object -> String -> Loaded object
loadRaw cache objectDecoder url =
  let resolveObject _ rawObject = Result.Ok rawObject
  in load cache objectDecoder resolveObject url

{-| Loads a list of model objects given their URLs from the given cache using an existing loader function.

    resolveLibrary : Cache -> RawLibrary -> Result Error Library
    resolveLibrary cache rawLibrary =
      let booksResult = rawLibrary.books |> loadList cache loadBook
      in
        booksResult |> Result.map (\books ->
          {
            books = books
          }
        )

    type alias RawLibrary = {
      books: List String
    }

    type alias Library = {
      books: List (Remote Book)
    }
-}
loadList : Cache -> (Cache -> String -> Loaded a) -> List String -> Result Error (List (Remote a))
loadList cache loadObject urls =
  let augment url objectsResult =
        let objectResult = url |> loadObject cache
        in Result.map2 (::) objectResult objectsResult
  in urls |> List.foldr augment (Ok [])
